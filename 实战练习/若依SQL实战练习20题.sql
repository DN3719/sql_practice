-- ============================================================================
-- 若依（RuoYi）ry 库 SQL 实战练习 · 20 题
-- ----------------------------------------------------------------------------
-- 适用环境：MySQL 8.0+ / 若依 RuoYi v4.8.3（sql/ry_20260319.sql）
-- 前置准备：
--   CREATE DATABASE ry;
--   导入 sql/ry_20260319.sql 和 sql/quartz.sql
-- 使用说明：
--   1. 每题先自己写，写完再对照下方的"参考答案"。
--   2. 本库 sys_user 中：login_name = 登录账号，user_name = 用户昵称。
--   3. 默认示例数据：用户 admin(1)/ry(2)；部门 100 若依科技为根节点。
--   4. sys_oper_log、sys_logininfor 默认是空表，相关题目附了"造数 SQL"。
--   5. 建议复制一个练习库（CREATE DATABASE ry_practice; 再导入），避免改坏原库。
-- 难度分级：1-6 基础 | 7-12 进阶 | 13-17 综合 | 18-20 挑战
-- ============================================================================


-- ============================================================================
-- 第一部分：基础（1-6）
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 题目 1：查询所有用户（sys_user），显示登录账号、昵称、性别、账号状态、
--         创建时间，按创建时间倒序排列。
-- ----------------------------------------------------------------------------
-- 参考答案：
SELECT login_name, user_name, sex, status, create_time
FROM sys_user
ORDER BY create_time DESC;


-- ----------------------------------------------------------------------------
-- 题目 2：查询研发部门（dept_id = 103）下状态正常（status = '0'）的用户，
--         显示登录账号、昵称、手机号。
-- ----------------------------------------------------------------------------
-- 参考答案：
SELECT login_name, user_name, phonenumber
FROM sys_user
WHERE dept_id = 103 AND status = '0';


-- ----------------------------------------------------------------------------
-- 题目 3：模糊查询：① 昵称中包含"若"的用户；② 登录账号中包含 admin 的用户。
-- ----------------------------------------------------------------------------
-- 参考答案：
SELECT login_name, user_name
FROM sys_user
WHERE user_name LIKE '%若%';

SELECT login_name, user_name
FROM sys_user
WHERE login_name LIKE '%admin%';


-- ----------------------------------------------------------------------------
-- 题目 4：sys_oper_log（操作日志）默认是空表，先造几条数据，
--         再查询有哪些不同的操作人员（去重）。
-- ----------------------------------------------------------------------------
-- 造数 SQL：
INSERT INTO sys_oper_log
  (title, business_type, method, request_method, oper_name, dept_name,
   oper_url, oper_ip, status, oper_time, cost_time)
VALUES
  ('用户管理', 1, 'update', 'POST', 'admin', '研发部门', '/system/user', '127.0.0.1', 0, NOW(), 120),
  ('用户管理', 1, 'update', 'POST', 'admin', '研发部门', '/system/user', '127.0.0.1', 0, NOW(), 90),
  ('角色管理', 3, 'delete', 'POST', 'ry',    '测试部门', '/system/role', '192.168.1.10', 0, NOW(), 60);

-- 参考答案：
SELECT DISTINCT oper_name
FROM sys_oper_log;


-- ----------------------------------------------------------------------------
-- 题目 5：分页查询：按 user_id 升序，每页 5 条，查询第 2 页。
-- ----------------------------------------------------------------------------
-- 参考答案：
SELECT user_id, login_name, user_name
FROM sys_user
ORDER BY user_id
LIMIT 5 OFFSET 5;


-- ----------------------------------------------------------------------------
-- 题目 6：查询最后登录时间最晚的 3 个用户（login_date 非空）。
-- ----------------------------------------------------------------------------
-- 参考答案：
SELECT login_name, user_name, login_date
FROM sys_user
WHERE login_date IS NOT NULL
ORDER BY login_date DESC
LIMIT 3;


-- ============================================================================
-- 第二部分：进阶（7-12）
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 题目 7：统计每个部门的用户数量，显示部门名称，按人数倒序排列。
-- ----------------------------------------------------------------------------
-- 参考答案：
SELECT d.dept_id, d.dept_name, COUNT(u.user_id) AS user_cnt
FROM sys_dept d
LEFT JOIN sys_user u ON u.dept_id = d.dept_id
GROUP BY d.dept_id, d.dept_name
ORDER BY user_cnt DESC;


-- ----------------------------------------------------------------------------
-- 题目 8：在上面统计的基础上，只显示用户数 >= 1 的部门（HAVING）。
-- ----------------------------------------------------------------------------
-- 参考答案：
SELECT d.dept_id, d.dept_name, COUNT(u.user_id) AS user_cnt
FROM sys_dept d
LEFT JOIN sys_user u ON u.dept_id = d.dept_id
GROUP BY d.dept_id, d.dept_name
HAVING COUNT(u.user_id) >= 1
ORDER BY user_cnt DESC;


-- ----------------------------------------------------------------------------
-- 题目 9：多表 JOIN：列出所有用户的登录账号、昵称、所属部门名称、
--         以及岗位名称（用户与岗位是多对多，通过 sys_user_post 关联）。
-- ----------------------------------------------------------------------------
-- 参考答案：
SELECT u.login_name, u.user_name, d.dept_name, p.post_name
FROM sys_user u
LEFT JOIN sys_dept d        ON u.dept_id = d.dept_id
LEFT JOIN sys_user_post up  ON u.user_id = up.user_id
LEFT JOIN sys_post p        ON up.post_id = p.post_id
ORDER BY u.user_id;


-- ----------------------------------------------------------------------------
-- 题目 10：子查询：查询昵称中包含"若"的用户所在的部门名称。
-- ----------------------------------------------------------------------------
-- 参考答案：
SELECT dept_id, dept_name
FROM sys_dept
WHERE dept_id IN (
    SELECT dept_id
    FROM sys_user
    WHERE user_name LIKE '%若%'
);


-- ----------------------------------------------------------------------------
-- 题目 11：EXISTS：sys_logininfor（登录日志）默认是空表，先造几条数据，
--          再查询哪些用户有过登录记录。
-- ----------------------------------------------------------------------------
-- 造数 SQL：
INSERT INTO sys_logininfor
  (login_name, ipaddr, login_location, browser, os, status, msg, login_time)
VALUES
  ('admin', '127.0.0.1',   '内网IP', 'Chrome',  'Windows 10', '0', '登录成功', NOW() - INTERVAL 1 HOUR),
  ('ry',    '192.168.1.1', '内网IP', 'Firefox', 'Windows 10', '0', '登录成功', NOW() - INTERVAL 2 HOUR),
  ('admin', '127.0.0.1',   '内网IP', 'Chrome',  'Windows 10', '0', '登录成功', NOW() - INTERVAL 1 DAY);

-- 参考答案：
SELECT u.login_name, u.user_name
FROM sys_user u
WHERE EXISTS (
    SELECT 1
    FROM sys_logininfor l
    WHERE l.login_name = u.login_name
);


-- ----------------------------------------------------------------------------
-- 题目 12：联表聚合：统计每个角色下的用户数量
--          （sys_role → sys_user_role → sys_user），按人数倒序。
-- ----------------------------------------------------------------------------
-- 参考答案：
SELECT r.role_id, r.role_name, COUNT(ur.user_id) AS user_cnt
FROM sys_role r
LEFT JOIN sys_user_role ur ON r.role_id = ur.role_id
GROUP BY r.role_id, r.role_name
ORDER BY user_cnt DESC;


-- ============================================================================
-- 第三部分：综合（13-17）
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 题目 13：权限模型：查询用户 admin（user_id = 1）拥有的所有菜单及权限标识。
--          涉及四表关联：sys_menu × sys_role_menu × sys_user_role × sys_role。
--          （这也是若依权限校验的核心查询逻辑）
-- ----------------------------------------------------------------------------
-- 参考答案：
SELECT DISTINCT m.menu_id, m.menu_name, m.perms
FROM sys_menu m
JOIN sys_role_menu rm ON m.menu_id = rm.menu_id
JOIN sys_user_role ur ON rm.role_id = ur.role_id
JOIN sys_role r       ON r.role_id = ur.role_id
WHERE ur.user_id = 1
  AND m.visible = '0'
  AND r.status  = '0'
ORDER BY m.parent_id, m.order_num;


-- ----------------------------------------------------------------------------
-- 题目 14：树形查询（自连接）：列出所有菜单及其父菜单名称。
-- ----------------------------------------------------------------------------
-- 参考答案：
SELECT m.menu_id, m.menu_name, p.menu_name AS parent_name
FROM sys_menu m
LEFT JOIN sys_menu p ON m.parent_id = p.menu_id
ORDER BY m.menu_id;


-- ----------------------------------------------------------------------------
-- 题目 15：递归 CTE：查询"深圳总公司"（dept_id = 101）及其所有下级部门，
--          并显示部门层级（lvl）。
-- ----------------------------------------------------------------------------
-- 参考答案：
WITH RECURSIVE dept_tree AS (
    SELECT dept_id, parent_id, dept_name, 1 AS lvl
    FROM sys_dept
    WHERE dept_id = 101

    UNION ALL

    SELECT d.dept_id, d.parent_id, d.dept_name, t.lvl + 1
    FROM sys_dept d
    JOIN dept_tree t ON d.parent_id = t.dept_id
)
SELECT dept_id, dept_name, lvl
FROM dept_tree
ORDER BY lvl, dept_id;


-- ----------------------------------------------------------------------------
-- 题目 16：CASE 表达式：查询用户，把性别（0男 1女 2未知）和
--          账号状态（0正常 1停用）翻译成中文。
-- ----------------------------------------------------------------------------
-- 参考答案：
SELECT login_name,
       user_name,
       CASE sex
           WHEN '0' THEN '男'
           WHEN '1' THEN '女'
           ELSE '未知'
       END AS sex_text,
       CASE status
           WHEN '0' THEN '正常'
           ELSE '停用'
       END AS status_text
FROM sys_user;


-- ----------------------------------------------------------------------------
-- 题目 17：时间函数：按"年月"统计登录次数；再统计最近 7 天每天的登录次数。
--          （若还未造数据，请先执行题目 11 的造数 SQL）
-- ----------------------------------------------------------------------------
-- 参考答案（按年月）：
SELECT DATE_FORMAT(login_time, '%Y-%m') AS ym,
       COUNT(*)                          AS login_cnt
FROM sys_logininfor
GROUP BY DATE_FORMAT(login_time, '%Y-%m')
ORDER BY ym;

-- 参考答案（最近 7 天每天）：
SELECT DATE(login_time)          AS login_date,
       COUNT(*)                  AS login_cnt
FROM sys_logininfor
WHERE login_time >= CURDATE() - INTERVAL 7 DAY
GROUP BY DATE(login_time)
ORDER BY login_date;


-- ============================================================================
-- 第四部分：挑战（18-20）
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 题目 18：窗口函数：按部门分组，对部门内用户编号（ROW_NUMBER）；
--          再按登录时间对全表用户排名（RANK）。
-- ----------------------------------------------------------------------------
-- 参考答案（部门内编号）：
SELECT login_name,
       dept_id,
       ROW_NUMBER() OVER (PARTITION BY dept_id ORDER BY user_id) AS rn
FROM sys_user
ORDER BY dept_id, rn;

-- 参考答案（按最后登录时间排名）：
SELECT login_name,
       user_name,
       login_date,
       RANK() OVER (ORDER BY login_date DESC) AS login_rank
FROM sys_user
WHERE login_date IS NOT NULL;


-- ----------------------------------------------------------------------------
-- 题目 19：连续登录：找出连续 3 天都有登录记录的用户。
--          先造数据：admin 连续 3 天登录，ry 仅 1 天登录。
-- ----------------------------------------------------------------------------
-- 造数 SQL（执行前可先清空测试数据）：
-- DELETE FROM sys_logininfor;
INSERT INTO sys_logininfor (login_name, status, msg, login_time) VALUES
  ('admin', '0', '登录成功', CURDATE() - INTERVAL 2 DAY),
  ('admin', '0', '登录成功', CURDATE() - INTERVAL 1 DAY),
  ('admin', '0', '登录成功', CURDATE()),
  ('ry',    '0', '登录成功', CURDATE() - INTERVAL 1 DAY);

-- 参考答案（去重后取每天一条，再判断与 2 天前的记录是否正好相差 2 天）：
WITH daily AS (
    SELECT login_name, DATE(login_time) AS d
    FROM sys_logininfor
    GROUP BY login_name, DATE(login_time)
),
prev AS (
    SELECT login_name,
           d,
           LAG(d, 2) OVER (PARTITION BY login_name ORDER BY d) AS prev2
    FROM daily
)
SELECT DISTINCT login_name
FROM prev
WHERE DATEDIFF(d, prev2) = 2;


-- ----------------------------------------------------------------------------
-- 题目 20：性能优化：给 sys_oper_log 造 5 万条数据，
--          用 EXPLAIN 分析按 oper_name 查询的执行计划，对比建索引前后。
-- ----------------------------------------------------------------------------
-- 造数 SQL（MySQL 8.0 递归 CTE，生成 5 万条日志）：
WITH RECURSIVE seq(n) AS (
    SELECT 1
    UNION ALL
    SELECT n + 1 FROM seq WHERE n < 50000
)
INSERT INTO sys_oper_log
  (title, business_type, method, request_method, oper_name, dept_name,
   oper_url, oper_ip, status, oper_time, cost_time)
SELECT '批量测试', 0, 'test', 'GET',
       CONCAT('user', n % 100),           -- 只有 100 个不同操作人
       '研发部门', '/test', '127.0.0.1', 0,
       NOW() - INTERVAL n SECOND, n % 1000
FROM seq;

-- ① 建索引前：观察 type（应为 ALL 全表扫描）、rows、key
EXPLAIN SELECT * FROM sys_oper_log WHERE oper_name = 'user50';

-- ② 创建索引后：再观察 type（应为 ref）、key（命中新索引）
CREATE INDEX idx_sys_oper_log_name ON sys_oper_log(oper_name);
EXPLAIN SELECT * FROM sys_oper_log WHERE oper_name = 'user50';

-- ③ 验证完可以清理索引（可选）：
-- DROP INDEX idx_sys_oper_log_name ON sys_oper_log;


-- ============================================================================
-- 结束：可以对照若依源码中的 Mapper XML 继续学习真实项目 SQL，
-- 目录：RuoYi/ruoyi-system/src/main/resources/mapper/system/
-- ============================================================================
