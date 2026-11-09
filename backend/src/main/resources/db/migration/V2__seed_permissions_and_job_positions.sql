-- Danh mục 14 permission và cấu hình mẫu cho vị trí việc làm.
-- ADMIN (users.role = 'ADMIN') có mọi permission, không cần cấu hình ở đây.
-- Tài khoản Admin đầu tiên tạo bằng ApplicationRunner từ biến môi trường, không tạo bằng SQL.

INSERT INTO permissions (code, name, module, description) VALUES
    ('user:read',                   'Xem tài khoản',                              'account',      'Xem danh sách, chi tiết tài khoản'),
    ('user:create',                 'Tạo tài khoản',                              'account',      NULL),
    ('user:update',                 'Sửa tài khoản',                              'account',      'Sửa thông tin tài khoản'),
    ('user:lock',                   'Khóa, mở khóa, vô hiệu hóa tài khoản',       'account',      NULL),
    ('user:reset-password',         'Đặt lại mật khẩu người khác',                'account',      NULL),
    ('department:read',             'Xem tất cả phòng ban',                       'organization', NULL),
    ('department:manage',           'Tạo, sửa, ngừng phòng ban',                  'organization', NULL),
    ('member:assign',               'Gán, đổi, kết thúc chức vụ TP/PP/NV',        'organization', NULL),
    ('job-position:manage',         'Sửa tên, mô tả vị trí việc làm',             'organization', 'Không gồm cấp/thu hồi permission (chỉ ADMIN)'),
    ('delegation:create-on-behalf', 'Tạo ủy quyền thay khi TP vắng đột xuất',     'delegation',   NULL),
    ('task:read-all',               'Xem toàn bộ task',                           'task',         'Chỉ xem, không tham gia duyệt'),
    ('kpi:read-all',                'Xem KPI mọi phòng',                          'kpi',          NULL),
    ('kpi:lock-period',             'Khóa kỳ KPI',                                'kpi',          NULL),
    ('audit:read',                  'Xem nhật ký hệ thống',                       'shared',       NULL);

INSERT INTO job_positions (code, name, description) VALUES
    ('SPECIALIST', 'Chuyên viên',                      'Vị trí chuyên môn, không có quyền quản trị'),
    ('HR_OFFICER', 'Chuyên viên tổ chức – nhân sự',    'Quản lý tài khoản, gán chức vụ, khóa kỳ KPI');

INSERT INTO job_position_permissions (job_position_id, permission_id)
SELECT jp.id, p.id
FROM job_positions jp
JOIN permissions p ON p.code IN (
    'user:read', 'user:create', 'user:update', 'user:lock', 'user:reset-password',
    'department:read', 'member:assign', 'job-position:manage',
    'delegation:create-on-behalf', 'task:read-all', 'kpi:read-all', 'kpi:lock-period'
)
WHERE jp.code = 'HR_OFFICER';
