-- Module 1 (Tài khoản & phân quyền) và module 2 (Tổ chức).
-- Thiết kế: backend/instruction/database.md, backend/instruction/erd-rbac.html

-- ===== account =====
CREATE TABLE users (
    id                     BIGINT GENERATED ALWAYS AS IDENTITY,
    username               VARCHAR(50)  NOT NULL,
    email                  VARCHAR(255) NOT NULL,
    password_hash          VARCHAR(100) NOT NULL,
    full_name              VARCHAR(150) NOT NULL,
    phone                  VARCHAR(20),
    role                   VARCHAR(20)  NOT NULL DEFAULT 'MEMBER',
    status                 VARCHAR(20)  NOT NULL DEFAULT 'ACTIVE',
    failed_login_attempts  INT          NOT NULL DEFAULT 0,
    locked_until           TIMESTAMPTZ,
    password_changed_at    TIMESTAMPTZ,
    last_login_at          TIMESTAMPTZ,
    created_at             TIMESTAMPTZ  NOT NULL DEFAULT now(),
    created_by             BIGINT,
    updated_at             TIMESTAMPTZ  NOT NULL DEFAULT now(),
    updated_by             BIGINT,
    CONSTRAINT pk_users PRIMARY KEY (id),
    CONSTRAINT ck_users_role   CHECK (role IN ('ADMIN', 'MEMBER')),
    CONSTRAINT ck_users_status CHECK (status IN ('ACTIVE', 'LOCKED', 'DISABLED')),
    CONSTRAINT ck_users_failed_login_attempts CHECK (failed_login_attempts >= 0),
    CONSTRAINT fk_users_created_by FOREIGN KEY (created_by) REFERENCES users (id),
    CONSTRAINT fk_users_updated_by FOREIGN KEY (updated_by) REFERENCES users (id)
);
-- Username, email duy nhất không phân biệt hoa thường
CREATE UNIQUE INDEX uk_users_username ON users (lower(username));
CREATE UNIQUE INDEX uk_users_email    ON users (lower(email));

-- Danh mục permission: chỉ seed bằng migration, không có API thêm/xóa
CREATE TABLE permissions (
    id          BIGINT GENERATED ALWAYS AS IDENTITY,
    code        VARCHAR(60)  NOT NULL,
    name        VARCHAR(150) NOT NULL,
    module      VARCHAR(30)  NOT NULL,
    description VARCHAR(255),
    CONSTRAINT pk_permissions PRIMARY KEY (id),
    CONSTRAINT uk_permissions_code UNIQUE (code)
);

-- ===== organization =====
CREATE TABLE departments (
    id          BIGINT GENERATED ALWAYS AS IDENTITY,
    code        VARCHAR(30)  NOT NULL,
    name        VARCHAR(150) NOT NULL,
    description VARCHAR(500),
    status      VARCHAR(20)  NOT NULL DEFAULT 'ACTIVE',
    created_at  TIMESTAMPTZ  NOT NULL DEFAULT now(),
    created_by  BIGINT,
    updated_at  TIMESTAMPTZ  NOT NULL DEFAULT now(),
    updated_by  BIGINT,
    CONSTRAINT pk_departments PRIMARY KEY (id),
    CONSTRAINT uk_departments_code UNIQUE (code),
    CONSTRAINT ck_departments_status CHECK (status IN ('ACTIVE', 'INACTIVE')),
    CONSTRAINT fk_departments_created_by FOREIGN KEY (created_by) REFERENCES users (id),
    CONSTRAINT fk_departments_updated_by FOREIGN KEY (updated_by) REFERENCES users (id)
);

CREATE TABLE job_positions (
    id          BIGINT GENERATED ALWAYS AS IDENTITY,
    code        VARCHAR(30)  NOT NULL,
    name        VARCHAR(150) NOT NULL,
    description VARCHAR(500),
    active      BOOLEAN      NOT NULL DEFAULT TRUE,
    created_at  TIMESTAMPTZ  NOT NULL DEFAULT now(),
    created_by  BIGINT,
    updated_at  TIMESTAMPTZ  NOT NULL DEFAULT now(),
    updated_by  BIGINT,
    CONSTRAINT pk_job_positions PRIMARY KEY (id),
    CONSTRAINT uk_job_positions_code UNIQUE (code),
    CONSTRAINT fk_job_positions_created_by FOREIGN KEY (created_by) REFERENCES users (id),
    CONSTRAINT fk_job_positions_updated_by FOREIGN KEY (updated_by) REFERENCES users (id)
);

-- Cấu hình permission cho từng vị trí việc làm (chỉ ADMIN sửa)
CREATE TABLE job_position_permissions (
    job_position_id BIGINT      NOT NULL,
    permission_id   BIGINT      NOT NULL,
    granted_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    granted_by      BIGINT,
    CONSTRAINT pk_job_position_permissions PRIMARY KEY (job_position_id, permission_id),
    CONSTRAINT fk_job_position_permissions_job_position
        FOREIGN KEY (job_position_id) REFERENCES job_positions (id) ON DELETE CASCADE,
    CONSTRAINT fk_job_position_permissions_permission
        FOREIGN KEY (permission_id) REFERENCES permissions (id) ON DELETE CASCADE,
    CONSTRAINT fk_job_position_permissions_granted_by
        FOREIGN KEY (granted_by) REFERENCES users (id)
);
CREATE INDEX ix_job_position_permissions_permission_id ON job_position_permissions (permission_id);

-- Mỗi dòng là một giai đoạn giữ chức vụ trong một phòng
CREATE TABLE department_members (
    id              BIGINT GENERATED ALWAYS AS IDENTITY,
    department_id   BIGINT       NOT NULL,
    user_id         BIGINT       NOT NULL,
    position        VARCHAR(20)  NOT NULL,
    job_position_id BIGINT,
    started_at      TIMESTAMPTZ  NOT NULL DEFAULT now(),
    ended_at        TIMESTAMPTZ,
    end_reason      VARCHAR(255),
    assigned_by     BIGINT,
    created_at      TIMESTAMPTZ  NOT NULL DEFAULT now(),
    CONSTRAINT pk_department_members PRIMARY KEY (id),
    CONSTRAINT ck_department_members_position CHECK (position IN ('HEAD', 'DEPUTY', 'STAFF')),
    CONSTRAINT ck_department_members_period   CHECK (ended_at IS NULL OR ended_at > started_at),
    CONSTRAINT fk_department_members_department   FOREIGN KEY (department_id)   REFERENCES departments (id),
    CONSTRAINT fk_department_members_user         FOREIGN KEY (user_id)         REFERENCES users (id),
    CONSTRAINT fk_department_members_job_position FOREIGN KEY (job_position_id) REFERENCES job_positions (id),
    CONSTRAINT fk_department_members_assigned_by  FOREIGN KEY (assigned_by)     REFERENCES users (id)
);
-- Mỗi người chỉ một chức vụ đang hiệu lực
CREATE UNIQUE INDEX uk_department_members_active_user
    ON department_members (user_id) WHERE ended_at IS NULL;
-- Mỗi phòng chỉ một TP đang hiệu lực
CREATE UNIQUE INDEX uk_department_members_active_head
    ON department_members (department_id) WHERE position = 'HEAD' AND ended_at IS NULL;
CREATE INDEX ix_department_members_department_id   ON department_members (department_id);
CREATE INDEX ix_department_members_job_position_id ON department_members (job_position_id);

-- ===== shared =====
-- Nhật ký thao tác quản trị: chỉ thêm, không sửa, không xóa
CREATE TABLE audit_logs (
    id          BIGINT GENERATED ALWAYS AS IDENTITY,
    actor_id    BIGINT,
    action      VARCHAR(50)  NOT NULL,
    target_type VARCHAR(50),
    target_id   BIGINT,
    old_value   JSONB,
    new_value   JSONB,
    reason      VARCHAR(500),
    ip_address  VARCHAR(45),
    created_at  TIMESTAMPTZ  NOT NULL DEFAULT now(),
    CONSTRAINT pk_audit_logs PRIMARY KEY (id),
    CONSTRAINT fk_audit_logs_actor FOREIGN KEY (actor_id) REFERENCES users (id)
);
CREATE INDEX ix_audit_logs_target     ON audit_logs (target_type, target_id);
CREATE INDEX ix_audit_logs_actor_id   ON audit_logs (actor_id);
CREATE INDEX ix_audit_logs_created_at ON audit_logs (created_at);
