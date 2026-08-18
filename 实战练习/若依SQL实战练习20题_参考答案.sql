-- ============================================================================
-- 若依（RuoYi）ry 库 SQL 实战练习 · 20 题（参考答案版）
-- ----------------------------------------------------------------------------
-- 使用说明：
--   1. 建议先独立完成题目文件中的 20 题，再对照本文件。
--   2. 题目 4、11、19、20 依赖造数 SQL，请先执行题目文件里对应的造数 SQL。
--   3. 答案直接可执行，方便核对结果。
-- ============================================================================


-- ============================================================================
-- 第一部分：基础（1-6）
-- ============================================================================

-- 题目 1 参考答案：查询所有用户，按创建时间倒序
SELECT login_name, user_name, sex, status, create_time
FROM sys_user
ORDER BY create_time DESC;


-- 题目 2 参考答案：研发部门下状态正常的用户
SELECT login_name, user_name, phonenumber
FROM sys_user
WHERE dept_id = 103 AND status = '0';


-- 题目 3 参考答案：模糊查询
SELECT login_name, user_name
FROM sys_user
WHERE user_name LIKE '%若%';

SELECT login_name, user_name
FROM sys_user
WHERE login_name LIKE '%admin%';


-- 题目 4 参考答案：操作人员去重（先执行题目文件中的造数 SQL）
SELECT DISTINCT oper_name
FROM sys_oper_log;


-- 题目 5 参考答案：分页，每页 5 条，第 2 页
SELECT user_id, login_name, user_name
FROM sys_user
ORDER BY user_id
LIMIT 5 OFFSET 5;


-- 题目 6 参考答案：最后登录时间最晚的 3 个用户
SELECT login_name, user_name, login_date
FROM sys_user
WHERE login_date IS NOT NULL
ORDER BY login_date DESC
LIMIT 3;


-- ============================================================================
-- 第二部分：进阶（7-12）
-- ============================================================================

-- 题目 7 参考答案：统计各部门用户数量
SELECT d.dept_id, d.dept_name, COUNT(u.user_id) AS user_cnt
FROM sys_dept d
LEFT JOIN sys_user u ON u.dept_id = d.dept_id
GROUP BY d.dept_id, d.dept_name
ORDER BY user_cnt DESC;


-- 题目 8 参考答案：只显示用户数 >= 1 的部门（HAVING）
SELECT d.dept_id, d.dept_name, COUNT(u.user_id) AS user_cnt
FROM sys_dept d
LEFT JOIN sys_user u ON u.dept_id = d.dept_id
GROUP BY d.dept_id, d.dept_name
HAVING COUNT(u.user_id) >= 1
ORDER BY user_cnt DESC;


-- 题目 9 参考答案：用户 + 部门 + 岗位（多对多）
SELECT u.login_name, u.user_name, d.dept_name, p.post_name
FROM sys_user u
LEFT JOIN sys_dept d        ON u.dept_id = d.dept_id
LEFT JOIN sys_user_post up  ON u.user_id = up.user_id
LEFT JOIN sys_post p        ON up.post_id = p.post_id
ORDER BY u.user_id;


-- 题目 10 参考答案：子查询
SELECT dept_id, dept_name
FROM sys_dept
WHERE dept_id IN (
    SELECT dept_id
    FROM sys_user
    WHERE user_name LIKE '%若%'
);


-- 题目 11 参考答案：EXISTS（先执行题目文件中的造数 SQL）
SELECT u.login_name, u.user_name
FROM sys_user u
WHERE EXISTS (
    SELECT 1
    FROM sys_logininfor l
    WHERE l.login_name = u.login_name
);


-- 题目 12 参考答案：统计每个角色的用户数量
SELECT r.role_id, r.role_name, COUNT(ur.user_id) AS user_cnt
FROM sys_role r
LEFT JOIN sys_user_role ur ON r.role_id = ur.role_id
GROUP BY r.role_id, r.role_name
ORDER BY user_cnt DESC;


-- ============================================================================
-- 第三部分：综合（13-17）
-- ============================================================================

-- 题目 13 参考答案：用户 admin 的菜单及权限（四表 JOIN）
SELECT DISTINCT m.menu_id, m.menu_name, m.perms
FROM sys_menu m
JOIN sys_role_menu rm ON m.menu_id = rm.menu_id
JOIN sys_user_role ur ON rm.role_id = ur.role_id
JOIN sys_role r       ON r.role_id = ur.role_id
WHERE ur.user_id = 1
  AND m.visible = '0'
  AND r.status  = '0'
ORDER BY m.parent_id, m.order_num;


-- 题目 14 参考答案：菜单树（自连接）
SELECT m.menu_id, m.menu_name, p.menu_name AS parent_name
FROM sys_menu m
LEFT JOIN sys_menu p ON m.parent_id = p.menu_id
ORDER BY m.menu_id;


-- 题目 15 参考答案：递归 CTE 查询部门树
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


-- 题目 16 参考答案：CASE 翻译性别和状态
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


-- 题目 17 参考答案：时间函数（先执行题目 11 的造数 SQL）
-- 按年月统计：
SELECT DATE_FORMAT(login_time, '%Y-%m') AS ym,
       COUNT(*)                          AS login_cnt
FROM sys_logininfor
GROUP BY DATE_FORMAT(login_time, '%Y-%m')
ORDER BY ym;

-- 最近 7 天每天统计：
SELECT DATE(login_time)          AS login_date,
       COUNT(*)                  AS login_cnt
FROM sys_logininfor
WHERE login_time >= CURDATE() - INTERVAL 7 DAY
GROUP BY DATE(login_time)
ORDER BY login_date;


-- ============================================================================
-- 第四部分：挑战（18-20）
-- ============================================================================

-- 题目 18 参考答案：窗口函数
-- 按部门分组编号：
SELECT login_name,
       dept_id,
       ROW_NUMBER() OVER (PARTITION BY dept_id ORDER BY user_id) AS rn
FROM sys_user
ORDER BY dept_id, rn;

-- 按最后登录时间排名：
SELECT login_name,
       user_name,
       login_date,
       RANK() OVER (ORDER BY login_date DESC) AS login_rank
FROM sys_user
WHERE login_date IS NOT NULL;


-- 题目 19 参考答案：连续 3 天登录（先执行题目文件中的造数 SQL）
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


-- 题目 20 参考答案：EXPLAIN 索引优化（先执行题目文件中的造数 SQL）
-- ① 建索引前：观察 type（应为 ALL 全表扫描）、rows、key
EXPLAIN SELECT * FROM sys_oper_log WHERE oper_name = 'user50';

-- ② 创建索引后：再观察 type（应为 ref）、key（命中新索引）
CREATE INDEX idx_sys_oper_log_name ON sys_oper_log(oper_name);
EXPLAIN SELECT * FROM sys_oper_log WHERE oper_name = 'user50';

-- ③ 验证完可以清理索引（可选）：
-- DROP INDEX idx_sys_oper_log_name ON sys_oper_log;


-- ============================================================================
-- 结束。
-- ============================================================================
