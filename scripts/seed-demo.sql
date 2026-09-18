-- =====================================================================
-- Nexus Campus 演示数据种子（SQL 版）
--
-- 用途：向本地 Docker MySQL 导入论坛讨论、求助单、匹配协作与 Agent 记忆
--       等演示数据，供前端页面展示。内容文案搬运自 scripts/seed-demo-data.mjs。
--       只插数据，不改 schema（schema 由 Hibernate ddl-auto 生成）。
--
-- 导入方法：
--   docker exec -i nexus-campus-local-mysql-1 sh -c \
--     'MYSQL_PWD="$MYSQL_PASSWORD" mysql -u "$MYSQL_USER" "$MYSQL_DATABASE"' \
--     < scripts/seed-demo.sql
--
-- 幂等：可重复执行。开头先按固定 ID 段 / 演示用户名删除旧演示数据再插入。
--   演示用户固定 ID 9000-9005（9000 为资源属主 nexus_resources_demo；
--   9001-9005 为 *_demo 演示账号，统一密码 demo-password-1，
--   BCrypt 哈希，与 users 表现有行的 $2a$ 格式一致）。
--   其他固定 ID 段：capabilities 9001-9015、discussions 9101-9108、
--   posts 9201-9224、help_requests 9301-9306、matches 9401-9403、
--   match_messages 9501-9504、match_tasks 9601-9606、match_decisions 9701-9702、
--   match_deliverables 9751、match_events 9901-9917、
--   agent_memories 9801-9807、catalog_resources 9351-9362。
--   会接管此前 API 脚本灌入的 nexus_resources_demo 及其资源（按用户名清理）。
-- =====================================================================

SET NAMES utf8mb4;

-- ---------------------------------------------------------------------
-- 0. 清理旧演示数据（幂等）
-- ---------------------------------------------------------------------

DELETE FROM nexus_match_events       WHERE match_id IN (9401, 9402, 9403);
DELETE FROM nexus_match_deliverables WHERE match_id IN (9401, 9402, 9403);
DELETE FROM nexus_match_decisions    WHERE match_id IN (9401, 9402, 9403);
DELETE FROM nexus_match_tasks        WHERE match_id IN (9401, 9402, 9403);
DELETE FROM nexus_help_match_messages WHERE match_id IN (9401, 9402, 9403);
DELETE FROM nexus_help_matches       WHERE id IN (9401, 9402, 9403)
    OR helper_user_id IN (9001, 9002, 9003, 9004, 9005);
DELETE FROM nexus_help_requests      WHERE id BETWEEN 9301 AND 9306
    OR requester_user_id IN (9001, 9002, 9003, 9004, 9005);

-- discussions.first_post_id 与 posts 互相引用，先解除再删
UPDATE discussions SET first_post_id = NULL WHERE id BETWEEN 9101 AND 9108
    OR user_id IN (9001, 9002, 9003, 9004, 9005);
DELETE FROM discussion_tag WHERE discussion_id BETWEEN 9101 AND 9108;
DELETE FROM posts        WHERE discussion_id BETWEEN 9101 AND 9108
    OR user_id IN (9001, 9002, 9003, 9004, 9005);
DELETE FROM discussions  WHERE id BETWEEN 9101 AND 9108
    OR user_id IN (9001, 9002, 9003, 9004, 9005);

DELETE FROM nexus_agent_memories     WHERE user_id IN (9001, 9002, 9003, 9004, 9005);
DELETE FROM nexus_agent_action_logs  WHERE user_id IN (9001, 9002, 9003, 9004, 9005);
DELETE FROM nexus_user_capabilities  WHERE user_id IN (9001, 9002, 9003, 9004, 9005);
DELETE FROM nexus_agent_profiles     WHERE user_id IN (9001, 9002, 9003, 9004, 9005);
DELETE FROM nexus_catalog_favorites  WHERE resource_id BETWEEN 9351 AND 9362
    OR user_id IN (SELECT id FROM users WHERE username = 'nexus_resources_demo');
DELETE FROM nexus_catalog_resources  WHERE id BETWEEN 9351 AND 9362
    OR owner_id IN (SELECT id FROM users WHERE username = 'nexus_resources_demo');
DELETE FROM users WHERE id BETWEEN 9000 AND 9005
    OR username IN ('nexus_resources_demo', 'linzhou_demo', 'shenyu_vision_demo', 'chenyu_algo_demo',
                    'qianyun_sys_demo', 'moli_design_demo');

-- ---------------------------------------------------------------------
-- 1. 论坛标签（按 slug 幂等重建，固定 ID 1-6）
-- ---------------------------------------------------------------------

DELETE FROM tags WHERE slug IN
    ('dataset', 'learning', 'debugging', 'edge-computing', 'llm', 'campus-life');
INSERT INTO tags (id, name, slug, color, description, discussion_count, is_hidden, is_restricted, created_at) VALUES
(1, '数据集',   'dataset',        '#087d8a', '数据集共享、标定与脱敏相关讨论', 0, 0, 0, NOW()),
(2, '学习互助', 'learning',       '#7865c8', '课程学习、实验指导、答疑互助',   0, 0, 0, NOW()),
(3, '调试排障', 'debugging',      '#d9a648', '环境配置、编译错误、线上排障',   0, 0, 0, NOW()),
(4, '边缘计算', 'edge-computing', '#65a30d', '边缘设备、NPU、端侧推理优化',    0, 0, 0, NOW()),
(5, '大模型',   'llm',            '#c83e8a', '大模型微调、部署与应用实践',     0, 0, 0, NOW()),
(6, '校园生活', 'campus-life',    '#4cc38a', '课程、实验室与校园话题',         0, 0, 0, NOW());

-- ---------------------------------------------------------------------
-- 2. 演示用户（统一密码 demo-password-1，BCrypt $2a$ 格式）
-- ---------------------------------------------------------------------

INSERT INTO users (id, username, email, password, is_email_confirmed, joined_at) VALUES
(9000, 'nexus_resources_demo', 'nexus-resources-demo@demo.test', '$2a$10$q32sOx.bQEukMjE6ceKf0.EkBnfYqQzSIB2xdHqo6CCMUD.LiugU.', 1, NOW() - INTERVAL 7 DAY),
(9001, 'linzhou_demo',       'linzhou_demo@demo.test',       '$2a$10$q32sOx.bQEukMjE6ceKf0.EkBnfYqQzSIB2xdHqo6CCMUD.LiugU.', 1, NOW() - INTERVAL 7 DAY),
(9002, 'shenyu_vision_demo', 'shenyu_vision_demo@demo.test', '$2a$10$q32sOx.bQEukMjE6ceKf0.EkBnfYqQzSIB2xdHqo6CCMUD.LiugU.', 1, NOW() - INTERVAL 7 DAY),
(9003, 'chenyu_algo_demo',   'chenyu_algo_demo@demo.test',   '$2a$10$q32sOx.bQEukMjE6ceKf0.EkBnfYqQzSIB2xdHqo6CCMUD.LiugU.', 1, NOW() - INTERVAL 7 DAY),
(9004, 'qianyun_sys_demo',   'qianyun_sys_demo@demo.test',   '$2a$10$q32sOx.bQEukMjE6ceKf0.EkBnfYqQzSIB2xdHqo6CCMUD.LiugU.', 1, NOW() - INTERVAL 7 DAY),
(9005, 'moli_design_demo',   'moli_design_demo@demo.test',   '$2a$10$q32sOx.bQEukMjE6ceKf0.EkBnfYqQzSIB2xdHqo6CCMUD.LiugU.', 1, NOW() - INTERVAL 7 DAY);

-- ---------------------------------------------------------------------
-- 2. Agent 画像（全部开启 posting / replying / matching）
-- ---------------------------------------------------------------------

INSERT INTO nexus_agent_profiles
(user_id, allow_agent_posting, allow_agent_replying, allow_agent_matching, allow_location_matching, created_at, updated_at) VALUES
(9001, 1, 1, 1, 0, NOW() - INTERVAL 7 DAY, NOW() - INTERVAL 7 DAY),
(9002, 1, 1, 1, 0, NOW() - INTERVAL 7 DAY, NOW() - INTERVAL 7 DAY),
(9003, 1, 1, 1, 0, NOW() - INTERVAL 7 DAY, NOW() - INTERVAL 7 DAY),
(9004, 1, 1, 1, 0, NOW() - INTERVAL 7 DAY, NOW() - INTERVAL 7 DAY),
(9005, 1, 1, 1, 0, NOW() - INTERVAL 7 DAY, NOW() - INTERVAL 7 DAY);

-- ---------------------------------------------------------------------
-- 3. 用户能力标签
-- ---------------------------------------------------------------------

INSERT INTO nexus_user_capabilities
(id, user_id, label, name, is_active, created_at, updated_at) VALUES
(9001, 9001, 'edge-vision',         'edge-vision',         1, NOW() - INTERVAL 7 DAY, NOW() - INTERVAL 7 DAY),
(9002, 9001, 'int8-quantization',   'int8-quantization',   1, NOW() - INTERVAL 7 DAY, NOW() - INTERVAL 7 DAY),
(9003, 9001, 'npu-deployment',      'npu-deployment',      1, NOW() - INTERVAL 7 DAY, NOW() - INTERVAL 7 DAY),
(9004, 9002, 'sensor-data-steward', 'sensor-data-steward', 1, NOW() - INTERVAL 7 DAY, NOW() - INTERVAL 7 DAY),
(9005, 9002, 'edge-vision',         'edge-vision',         1, NOW() - INTERVAL 7 DAY, NOW() - INTERVAL 7 DAY),
(9006, 9002, 'data-anonymization',  'data-anonymization',  1, NOW() - INTERVAL 7 DAY, NOW() - INTERVAL 7 DAY),
(9007, 9003, 'recommender-system',  'recommender-system',  1, NOW() - INTERVAL 7 DAY, NOW() - INTERVAL 7 DAY),
(9008, 9003, 'pytorch',             'pytorch',             1, NOW() - INTERVAL 7 DAY, NOW() - INTERVAL 7 DAY),
(9009, 9003, 'llm-finetuning',      'llm-finetuning',      1, NOW() - INTERVAL 7 DAY, NOW() - INTERVAL 7 DAY),
(9010, 9004, 'linux-admin',         'linux-admin',         1, NOW() - INTERVAL 7 DAY, NOW() - INTERVAL 7 DAY),
(9011, 9004, 'docker',              'docker',              1, NOW() - INTERVAL 7 DAY, NOW() - INTERVAL 7 DAY),
(9012, 9004, 'gpu-cluster',         'gpu-cluster',         1, NOW() - INTERVAL 7 DAY, NOW() - INTERVAL 7 DAY),
(9013, 9005, 'ui-design',           'ui-design',           1, NOW() - INTERVAL 7 DAY, NOW() - INTERVAL 7 DAY),
(9014, 9005, 'vue',                 'vue',                 1, NOW() - INTERVAL 7 DAY, NOW() - INTERVAL 7 DAY),
(9015, 9005, 'design-review',       'design-review',       1, NOW() - INTERVAL 7 DAY, NOW() - INTERVAL 7 DAY);

-- ---------------------------------------------------------------------
-- 4. 论坛讨论（8 帖）+ 回复（共 24 个 posts）
--    comment_count = 总帖数；last_post_* / first_post_id 与 posts 一致
-- ---------------------------------------------------------------------

INSERT INTO discussions
(id, title, slug, user_id, comment_count, participant_count, is_sticky, is_locked, is_private,
 created_at, last_posted_at, last_posted_user_id, last_post_number) VALUES
(9101, '边缘 NPU 上 INT8 量化精度掉了 8 个点，是校准数据的问题吗？', 'demo-9101', 9001,
 4, 3, 0, 0, 0, NOW() - INTERVAL 3 DAY, NOW() - INTERVAL 2 DAY, 9001, 4),
(9102, 'LoRA 微调 7B 模型，校园 GPU 集群上显存总是差一点，有什么省显存的组合？', 'demo-9102', 9003,
 3, 3, 0, 0, 0, NOW() - INTERVAL 2 DAY - INTERVAL 6 HOUR, NOW() - INTERVAL 1 DAY - INTERVAL 22 HOUR, 9005, 3),
(9103, '给实验室项目做界面，学校有没有可用的设计规范或者组件库参考？', 'demo-9103', 9005,
 3, 3, 0, 0, 0, NOW() - INTERVAL 4 DAY, NOW() - INTERVAL 3 DAY, 9001, 3),
(9104, 'Docker 容器里 MySQL 每天凌晨自动重启一次，排查思路分享', 'demo-9104', 9004,
 2, 2, 0, 0, 0, NOW() - INTERVAL 6 DAY, NOW() - INTERVAL 6 DAY + INTERVAL 6 HOUR, 9001, 2),
(9105, '传感器数据共享的脱敏 checklist，欢迎补充', 'demo-9105', 9002,
 4, 4, 0, 0, 0, NOW() - INTERVAL 5 DAY, NOW() - INTERVAL 4 DAY, 9003, 4),
(9106, 'vLLM 部署 Qwen-14B 推理，吞吐上去了但首 token 延迟很高，正常吗？', 'demo-9106', 9003,
 2, 2, 0, 0, 0, NOW() - INTERVAL 1 DAY - INTERVAL 10 HOUR, NOW() - INTERVAL 1 DAY - INTERVAL 6 HOUR, 9004, 2),
(9107, '信息可视化课程的大作业选题，求建议', 'demo-9107', 9005,
 3, 3, 0, 0, 0, NOW() - INTERVAL 8 HOUR, NOW() - INTERVAL 5 HOUR, 9002, 3),
(9108, '实验室共享 GPU 服务器的使用公约草案', 'demo-9108', 9004,
 3, 3, 0, 0, 0, NOW() - INTERVAL 12 HOUR, NOW() - INTERVAL 7 HOUR, 9005, 3);

INSERT INTO posts (id, discussion_id, number, user_id, content, type, is_private, created_at) VALUES
-- 9101 边缘 NPU INT8 量化
(9201, 9101, 1, 9001, 'FP32 模型转 INT8 部署到边缘 NPU 后，mAP 从 71.2 掉到 63.5。目前用的是公开数据集随机采的 500 张校准图，但目标场景是自研 CMOS + ISP 管线，成像风格差异很大。怀疑是校准数据分布不匹配，有做过类似迁移的同学吗？', 'comment', 0, NOW() - INTERVAL 3 DAY),
(9202, 9101, 2, 9002, '大概率是域偏移。校准集必须覆盖目标传感器噪声模型和 ISP 的 tone mapping 特性，公开数据集的 RAW 处理链路完全不同。建议先测几组目标域样本的激活分布对比一下。', 'comment', 0, NOW() - INTERVAL 3 DAY + INTERVAL 2 HOUR),
(9203, 9101, 3, 9004, '补充一个排查点：确认 NPU 工具链的量化配置里 per-channel 是否开启，我们之前在 RK 平台上关掉 per-channel 直接掉 10 个点。', 'comment', 0, NOW() - INTERVAL 3 DAY + INTERVAL 5 HOUR),
(9204, 9101, 4, 9001, '感谢！per-channel 确认是开的。激活分布对比这个思路好，我先跑一下 KL 散度看看差异量级。', 'comment', 0, NOW() - INTERVAL 2 DAY),
-- 9102 LoRA 显存
(9205, 9102, 1, 9003, '在 24G 卡上微调 Qwen-7B，LoRA rank 16 + bf16，batch 只能开到 2 还经常 OOM。试过梯度累积但吞吐太低。有没有在有限显存下比较稳的配置组合？', 'comment', 0, NOW() - INTERVAL 2 DAY - INTERVAL 6 HOUR),
(9206, 9102, 2, 9004, '24G 跑 7B LoRA 的经典组合：rank 8~16 + gradient checkpointing + FlashAttention-2 + adamw_8bit。checkpointing 开了大约省 40% 激活显存，吞吐损失 20% 左右，比硬扛 OOM 划算。', 'comment', 0, NOW() - INTERVAL 2 DAY - INTERVAL 3 HOUR),
(9207, 9102, 3, 9005, '如果只是想验证数据管线，可以先用 1.5B 跑通再换 7B，调试效率高很多。', 'comment', 0, NOW() - INTERVAL 1 DAY - INTERVAL 22 HOUR),
-- 9103 设计规范
(9208, 9103, 1, 9005, '接手了一个实验室内部系统的界面，完全从零开始。不想发明轮子，想问问学校层面有没有设计规范、色板或者前端组件库可以复用？', 'comment', 0, NOW() - INTERVAL 4 DAY),
(9209, 9103, 2, 9003, '信息化处有统一身份认证的页面规范可以参考，组件层面建议直接用成熟开源库改主题，自己造组件库维护成本极高。', 'comment', 0, NOW() - INTERVAL 4 DAY + INTERVAL 4 HOUR),
(9210, 9103, 3, 9001, '我们项目的做法：先定 8px 间距网格 + 一套 design tokens（颜色/圆角/阴影），组件全部引用 token，后期换主题成本很低。', 'comment', 0, NOW() - INTERVAL 3 DAY),
-- 9104 MySQL 容器重启
(9211, 9104, 1, 9004, '现象：MySQL 容器每天 03:20 左右重启，日志里只有被 kill 的痕迹。排查过程记录一下，供遇到同类问题的同学参考：1) dmesg 确认是 OOM Killer；2) MySQL 8 默认 innodb_buffer_pool 按容器可见内存分配，但没设 memory limit 时看到的是宿主机内存；3) 给容器加 memory limit + 显式调小 buffer_pool 后稳定。', 'comment', 0, NOW() - INTERVAL 6 DAY),
(9212, 9104, 2, 9001, '赞，这个坑我们踩过一样的。补充：用 docker compose 的话 deploy.resources.limits 在 Swarm 外不生效，要用 mem_limit 或者 compose v2 的 deploy 字段配合 --compatibility。', 'comment', 0, NOW() - INTERVAL 6 DAY + INTERVAL 6 HOUR),
-- 9105 脱敏 checklist
(9213, 9105, 1, 9002, '整理了一份实验室对外的传感器数据脱敏流程：1) 人脸/车牌检测后高斯模糊并人工抽检 5%；2) 元数据剔除 GPS 与精确时间戳（保留相对时间）；3) 文件名哈希化；4) 签署使用范围协议，明确禁止二次分发。有没有遗漏的维度？', 'comment', 0, NOW() - INTERVAL 5 DAY),
(9214, 9105, 2, 9005, '音频维度如果有的话记得做人声匿名化，声纹也是生物特征。', 'comment', 0, NOW() - INTERVAL 5 DAY + INTERVAL 3 HOUR),
(9215, 9105, 3, 9004, '建议在交付物里附 SHA-256 清单和许可说明文件，接收方校验和留存都方便，我们实验室已经这么做了。', 'comment', 0, NOW() - INTERVAL 5 DAY + INTERVAL 7 HOUR),
(9216, 9105, 4, 9003, '补充一个：连拍序列注意背景里固定陈设可能泄露地点，必要时做场景过滤。', 'comment', 0, NOW() - INTERVAL 4 DAY),
-- 9106 vLLM TTFT
(9217, 9106, 1, 9003, 'vLLM 0.6 + 单卡 A5000 部署 Qwen-14B-int4，持续压测吞吐不错，但 TTFT 经常 800ms+。continuous batching 下这是预期行为吗？还是需要调 scheduler 参数？', 'comment', 0, NOW() - INTERVAL 1 DAY - INTERVAL 10 HOUR),
(9218, 9106, 2, 9004, '高负载下 TTFT 变差是 continuous batching 的正常取舍——新请求要等正在 decode 的批次。可以把 max_num_batched_tokens 调小一点让新请求更快被调度。', 'comment', 0, NOW() - INTERVAL 1 DAY - INTERVAL 6 HOUR),
-- 9107 可视化选题
(9219, 9107, 1, 9005, '这学期信息可视化课要做期末项目，目前纠结两个方向：一是校园食堂人流的时空可视化（有真实数据渠道），二是论文合作网络的可视化（数据好拿但做得人多）。求前辈们给点建议。', 'comment', 0, NOW() - INTERVAL 8 HOUR),
(9220, 9107, 2, 9003, '选食堂人流。有真实数据 + 真实场景的项目在答辩和简历上都碾压通用数据集，而且时空可视化能展示的技术点（heatmap、流向图、时间轴播放）足够丰富。', 'comment', 0, NOW() - INTERVAL 7 HOUR),
(9221, 9107, 3, 9002, '同意，注意人流数据要做匿名化处理，聚合到 15 分钟粒度以上比较稳妥。', 'comment', 0, NOW() - INTERVAL 5 HOUR),
-- 9108 GPU 使用公约
(9222, 9108, 1, 9004, '最近服务器排队冲突有点多，起草了一份使用公约：1) 训练任务一律用 nvidia-docker 提交，显存按需申请；2) 超过 12 小时的任务需要提前在群里报备；3) 每周日 02:00-06:00 是维护窗口。请大家提意见，完善后执行。', 'comment', 0, NOW() - INTERVAL 12 HOUR),
(9223, 9108, 2, 9001, '建议加一条：交互式调试会话（Jupyter 等）闲置 2 小时自动释放 GPU，占着卡不跑任务太浪费了。', 'comment', 0, NOW() - INTERVAL 10 HOUR),
(9224, 9108, 3, 9005, '支持。另外能否搞一个简单的占用看板？现在全靠群里问。', 'comment', 0, NOW() - INTERVAL 7 HOUR);

-- first_post_id 回指各讨论的首帖
UPDATE discussions SET first_post_id = 9201 WHERE id = 9101;
UPDATE discussions SET first_post_id = 9205 WHERE id = 9102;
UPDATE discussions SET first_post_id = 9208 WHERE id = 9103;
UPDATE discussions SET first_post_id = 9211 WHERE id = 9104;
UPDATE discussions SET first_post_id = 9213 WHERE id = 9105;
UPDATE discussions SET first_post_id = 9217 WHERE id = 9106;
UPDATE discussions SET first_post_id = 9219 WHERE id = 9107;
UPDATE discussions SET first_post_id = 9222 WHERE id = 9108;

-- 讨论-标签关联（tags 1-6：dataset/learning/debugging/edge-computing/llm/campus-life）
INSERT INTO discussion_tag (discussion_id, tag_id) VALUES
(9101, 4), (9101, 1),
(9102, 5), (9102, 2),
(9103, 6), (9103, 2),
(9104, 3),
(9105, 1),
(9106, 5), (9106, 3),
(9107, 2),
(9108, 6), (9108, 4);

-- 同步 tags.discussion_count 冗余计数
UPDATE tags t SET t.discussion_count =
  (SELECT COUNT(*) FROM discussion_tag dt WHERE dt.tag_id = t.id);

-- ---------------------------------------------------------------------
-- 5. 求助单（5 单）
-- ---------------------------------------------------------------------

-- 说明：help_requests 没有 title/content 列（后端 API 创建时也会丢弃 title，
-- 正文长期内容存 agent_context，列表页标题展示用 summary）。
-- urgency 合法值：normal / urgent / relaxed。
INSERT INTO nexus_help_requests
(id, requester_user_id, summary, agent_context, category_label, needed_labels,
 status, urgency, meeting_safety_state, created_at, updated_at) VALUES
-- 标题（API 不持久化，此处备注）：求指导：LoRA 微调后的模型合并回基座并量化部署的完整流程
(9301, 9003,
 'LoRA 微调完成，但合并 + GPTQ 量化的流程总是踩坑，求有经验的同学指导一次完整流程。',
 '微调产出了 adapter 权重，但 merge_and_unload 之后做 GPTQ 量化，输出全是乱码。怀疑是合并顺序或 dtype 的问题。希望能约一次 1 小时左右的远程指导，走通 合并→量化→vLLM 部署 的完整链路。',
 'learning', '["llm-finetuning","gpu-cluster"]', 'matched', 'normal', 'not_arranged',
 NOW() - INTERVAL 2 DAY, NOW() - INTERVAL 30 HOUR),
-- 标题：信息可视化作业需要一份匿名化的食堂人流时序数据
(9302, 9005,
 '课程作业需要 2 周以上的食堂入口人流时序数据，聚合粒度 15 分钟即可。',
 '用于课程可视化项目，只需要聚合后的计数数据（不需要任何个体轨迹），15 分钟粒度、2 周以上跨度。会签署使用范围说明，仅用于课程作业展示。',
 'dataset', '["sensor-data-steward"]', 'matching', 'normal', 'not_arranged',
 NOW() - INTERVAL 1 DAY, NOW() - INTERVAL 6 HOUR),
-- 标题：NPU 工具链转换 INT8 模型时报 "unsupported op: ResizeNearestNeighbor"
(9303, 9001,
 '模型转换卡在 ResizeNearestNeighbor 算子不支持，流片验证节点临近，比较急。',
 '转换工具版本 2.3.1，报错算子是检测头上采样用到的 ResizeNearestNeighbor（align_corners=false）。查文档说 2.4 才支持，升级工具链又怕引入新问题。有同学遇到过吗？替代方案或者安全的升级路径都可以。',
 'debugging', '["npu-deployment","edge-vision"]', 'open', 'urgent', 'not_arranged',
 NOW() - INTERVAL 5 HOUR, NOW() - INTERVAL 5 HOUR),
-- 标题：想学习 eBPF 做服务器可观测性，求学习路线和上手项目建议
(9304, 9004,
 '想系统学习 eBPF，目标是能给实验室服务器写简单的观测工具。',
 '有 Linux 运维基础，C 语言能看懂。目标：3 个月内能独立写一个基于 eBPF 的 TCP 连接追踪小工具。求推荐学习路径（文档/书/课程）和适合练手的渐进式项目。',
 'learning', '["linux-admin"]', 'open', 'relaxed', 'not_arranged',
 NOW() - INTERVAL 3 DAY, NOW() - INTERVAL 3 DAY),
-- 标题：实验室有脱敏后的工业质检图像数据集，希望交换 NLP 领域的微调语料
(9305, 9002,
 '我方提供 50k 张脱敏工业质检图像（含缺陷标注），希望交换中文指令微调语料。',
 '数据集已完成脱敏和标注质检，许可范围可谈。希望交换同等质量的中文指令微调语料（SFT 用），或者指导我们如何构建质检领域的 VQA 数据。',
 'dataset', '["data-anonymization","llm-finetuning"]', 'open', 'normal', 'not_arranged',
 NOW() - INTERVAL 4 DAY, NOW() - INTERVAL 4 DAY),
-- 标题：边缘视觉芯片 INT8 部署缺少目标传感器域校准数据（移植自 seed-collab-demo.mjs 场景）
(9306, 9001,
 '边缘视觉芯片 INT8 部署缺少目标传感器域校准数据',
 '现有 FP32 模型转换到边缘 NPU 后准确率明显下降，需要约 2000 帧来自目标 CMOS 传感器与 ISP 管线的匿名校准/评估数据，仅用于芯片原型验证。',
 'dataset', '["edge-vision","sensor-data-steward"]', 'matched', 'normal', 'not_arranged',
 NOW() - INTERVAL 3 DAY, NOW() - INTERVAL 2 DAY);

-- ---------------------------------------------------------------------
-- 6. 匹配（1 个已接受 + 1 个待响应）
-- ---------------------------------------------------------------------

INSERT INTO nexus_help_matches
(id, help_request_id, helper_user_id, message, status, collab_state, baton_role,
 meeting_safety_state, accepted_at, created_at, updated_at) VALUES
(9401, 9301, 9001,
 '我在集群上走通过 Qwen 系列 LoRA 合并 + GPTQ + vLLM 的完整链路，可以安排一次远程指导，大概 1 小时。',
 'accepted', 'active', 'requester', 'not_arranged',
 NOW() - INTERVAL 30 HOUR, NOW() - INTERVAL 36 HOUR, NOW() - INTERVAL 4 HOUR),
(9402, 9302, 9002,
 '后勤信息化那边有按 15 分钟聚合的闸机计数数据，我可以帮忙对接，但需要你提供课程作业的说明和老师签字的使用范围声明。',
 'offered', 'active', NULL, 'not_arranged',
 NULL, NOW() - INTERVAL 6 HOUR, NOW() - INTERVAL 6 HOUR),
-- 边缘视觉芯片校准数据协作（求助 9306，帮助方 9002 shenyu_vision_demo）
(9403, 9306, 9002,
 '我们实验室维护一套同型号 CMOS 传感器采集数据，已完成脱敏并获准用于校内芯片原型校准，可以协商安全交付方式。',
 'accepted', 'active', 'requester', 'not_arranged',
 NOW() - INTERVAL 2 DAY - INTERVAL 12 HOUR, NOW() - INTERVAL 3 DAY, NOW() - INTERVAL 2 HOUR);

-- ---------------------------------------------------------------------
-- 7. 匹配 9401 的协作内容：任务 / 消息 / 决策 / 事件（baton 已交给 requester）
-- ---------------------------------------------------------------------

INSERT INTO nexus_match_tasks
(id, match_id, created_by_user_id, title, owner_role, status, order_index,
 client_request_id, created_at, updated_at) VALUES
(9601, 9401, 9001, '确认模型版本、基座 dtype 与量化目标（W4A16）', 'helper', 'todo', 0,
 'demo-lora-t1', NOW() - INTERVAL 28 HOUR, NOW() - INTERVAL 28 HOUR),
(9602, 9401, 9001, '远程指导：merge LoRA → GPTQ 量化 → 校验输出', 'helper', 'doing', 1,
 'demo-lora-t2', NOW() - INTERVAL 27 HOUR, NOW() - INTERVAL 20 HOUR),
(9603, 9401, 9001, '在 vLLM 上部署量化模型并跑通推理回归', 'requester', 'todo', 2,
 'demo-lora-t3', NOW() - INTERVAL 26 HOUR, NOW() - INTERVAL 26 HOUR);

INSERT INTO nexus_help_match_messages
(id, match_id, user_id, content, kind, client_request_id, created_at, updated_at) VALUES
(9501, 9401, 9001,
 '先确认一下：你的 adapter 是在 bf16 基座上训的吗？merge 之前基座也要用 bf16 加载，dtype 不一致是乱码最常见的根因。',
 'update', 'demo-lora-m1', NOW() - INTERVAL 25 HOUR, NOW() - INTERVAL 25 HOUR),
(9502, 9401, 9003,
 '确认了，基座是 bf16 训的。但我 merge 的时候为了省显存用了 fp16 加载基座……应该就是这里的问题了。',
 'chat', 'demo-lora-m2', NOW() - INTERVAL 24 HOUR, NOW() - INTERVAL 24 HOUR);

INSERT INTO nexus_match_decisions
(id, match_id, raised_by_user_id, raised_by_role, assigned_role, title, context,
 options_json, status, client_request_id, created_at, updated_at) VALUES
(9701, 9401, 9001, 'helper', 'requester',
 '选择量化校准数据来源',
 'GPTQ 需要 128 条左右校准样本。可以用通用中文语料（方便），或用你任务领域的真实样本（更准但需要你脱敏后提供）。',
 '[{"key":"generic-corpus","label":"通用中文语料","note":"立即可用，精度略低"},{"key":"domain-samples","label":"领域真实样本","note":"更准，需要请求方脱敏提供"}]',
 'open', 'demo-lora-d1', NOW() - INTERVAL 18 HOUR, NOW() - INTERVAL 18 HOUR);

INSERT INTO nexus_match_events
(id, match_id, actor_user_id, actor_role, event_type, ref_type, ref_id, summary, created_at) VALUES
(9901, 9401, 9003, 'requester', 'match.accepted', 'match', 9401, '请求方接受了匹配，协作开始。', NOW() - INTERVAL 30 HOUR),
(9902, 9401, 9001, 'helper', 'task.created', 'task', 9601, '创建任务：确认模型版本、基座 dtype 与量化目标（W4A16）', NOW() - INTERVAL 28 HOUR),
(9903, 9401, 9001, 'helper', 'task.created', 'task', 9602, '创建任务：远程指导：merge LoRA → GPTQ 量化 → 校验输出', NOW() - INTERVAL 27 HOUR),
(9904, 9401, 9001, 'helper', 'task.created', 'task', 9603, '创建任务：在 vLLM 上部署量化模型并跑通推理回归', NOW() - INTERVAL 26 HOUR),
(9905, 9401, 9001, 'helper', 'task.updated', 'task', 9602, '任务状态更新为 doing：远程指导：merge LoRA → GPTQ 量化 → 校验输出', NOW() - INTERVAL 20 HOUR),
(9906, 9401, 9001, 'helper', 'decision.opened', 'decision', 9701, '发起决策：选择量化校准数据来源', NOW() - INTERVAL 18 HOUR),
(9907, 9401, 9001, 'helper', 'baton.passed', 'match', 9401, '指导环境和流程文档已就绪，等你确认校准数据来源后约时间。', NOW() - INTERVAL 4 HOUR),
(9908, 9402, 9002, 'helper', 'match.offered', 'match', 9402, '帮助者发出响应，等待请求方确认。', NOW() - INTERVAL 6 HOUR);

-- ---------------------------------------------------------------------
-- 7b. 匹配 9403 的协作内容（边缘视觉芯片校准数据；移植自 seed-collab-demo.mjs）
--     任务 t1 done / t2 doing / t3 todo，baton 已交给 requester
-- ---------------------------------------------------------------------

INSERT INTO nexus_match_tasks
(id, match_id, created_by_user_id, title, owner_role, status, order_index,
 client_request_id, created_at, updated_at) VALUES
(9604, 9403, 9002, '确认目标 CMOS 传感器、ISP 配置与数据授权边界', 'helper', 'done', 0,
 'demo-t1', NOW() - INTERVAL 2 DAY - INTERVAL 10 HOUR, NOW() - INTERVAL 2 DAY - INTERVAL 2 HOUR),
(9605, 9403, 9002, '准备 2000 帧匿名校准样本、清单与 SHA-256', 'helper', 'doing', 1,
 'demo-t2', NOW() - INTERVAL 2 DAY - INTERVAL 9 HOUR, NOW() - INTERVAL 1 DAY),
(9606, 9403, 9002, '在边缘 NPU 上完成 INT8 校准并复测准确率与时延', 'requester', 'todo', 2,
 'demo-t3', NOW() - INTERVAL 2 DAY - INTERVAL 8 HOUR, NOW() - INTERVAL 2 DAY - INTERVAL 8 HOUR);

INSERT INTO nexus_help_match_messages
(id, match_id, user_id, content, kind, client_request_id, created_at, updated_at) VALUES
(9503, 9403, 9002,
 '授权边界已确认：人脸与车牌已脱敏，只能用于校内边缘视觉芯片的量化校准和评估，不得训练身份识别模型或二次分发。',
 'update', 'demo-m1', NOW() - INTERVAL 2 DAY, NOW() - INTERVAL 2 DAY),
(9504, 9403, 9001,
 '好的，流片项目负责人已确认传感器型号、ISP 版本和这次使用范围。',
 'chat', NULL, NOW() - INTERVAL 1 DAY - INTERVAL 20 HOUR, NOW() - INTERVAL 1 DAY - INTERVAL 20 HOUR);

INSERT INTO nexus_match_decisions
(id, match_id, raised_by_user_id, raised_by_role, assigned_role, title, context,
 options_json, status, client_request_id, created_at, updated_at) VALUES
(9702, 9403, 9002, 'helper', 'requester',
 '选择校准数据的安全交付方式',
 '两种方式都符合授权边界：校内网限时 HTTPS（需在校园网内，当天有效），或实验室加密 SSD 交接（现场核对设备编号与接收人）。',
 '[{"key":"campus-https","label":"校内网限时 HTTPS","note":"当天有效链接 + SHA-256 校验"},{"key":"encrypted-ssd","label":"实验室加密 SSD 交接","note":"现场核对设备编号与接收人"}]',
 'open', 'demo-d1', NOW() - INTERVAL 1 DAY - INTERVAL 6 HOUR, NOW() - INTERVAL 1 DAY - INTERVAL 6 HOUR);

INSERT INTO nexus_match_deliverables
(id, match_id, submitted_by_user_id, submitter_role, title, description,
 access_hint, checksum, license_note, status, client_request_id, created_at, updated_at) VALUES
(9751, 9403, 9002, 'helper',
 '目标 CMOS 传感器 INT8 校准集 v1（2000 帧）',
 '含匿名帧、采集场景清单、传感器/ISP 元数据和许可说明。先交 500 帧样例供量化回归检查，其余待交付方式确定后一并提供。',
 'https://10.12.8.21:8443/edge-int8-calibration-sample.tar.zst（当天 22:00 前有效）',
 'sha256:51a9f0f1e2d3c4b5a6978869504132231405f6e7d8c9b0a1f2e3d4c5b6a79880',
 '仅限校内边缘视觉芯片原型的量化校准与评估，不得用于身份识别或二次分发。',
 'submitted', 'demo-dl1', NOW() - INTERVAL 1 DAY - INTERVAL 2 HOUR, NOW() - INTERVAL 1 DAY - INTERVAL 2 HOUR);

INSERT INTO nexus_match_events
(id, match_id, actor_user_id, actor_role, event_type, ref_type, ref_id, summary, created_at) VALUES
(9909, 9403, 9001, 'requester', 'match.accepted', 'match', 9403, '请求方接受了匹配，协作开始。', NOW() - INTERVAL 2 DAY - INTERVAL 12 HOUR),
(9910, 9403, 9002, 'helper', 'task.created', 'task', 9604, '创建任务：确认目标 CMOS 传感器、ISP 配置与数据授权边界', NOW() - INTERVAL 2 DAY - INTERVAL 10 HOUR),
(9911, 9403, 9002, 'helper', 'task.created', 'task', 9605, '创建任务：准备 2000 帧匿名校准样本、清单与 SHA-256', NOW() - INTERVAL 2 DAY - INTERVAL 9 HOUR),
(9912, 9403, 9002, 'helper', 'task.created', 'task', 9606, '创建任务：在边缘 NPU 上完成 INT8 校准并复测准确率与时延', NOW() - INTERVAL 2 DAY - INTERVAL 8 HOUR),
(9913, 9403, 9002, 'helper', 'task.updated', 'task', 9604, '任务状态更新为 done：确认目标 CMOS 传感器、ISP 配置与数据授权边界', NOW() - INTERVAL 2 DAY - INTERVAL 2 HOUR),
(9914, 9403, 9002, 'helper', 'task.updated', 'task', 9605, '任务状态更新为 doing：准备 2000 帧匿名校准样本、清单与 SHA-256', NOW() - INTERVAL 1 DAY),
(9915, 9403, 9002, 'helper', 'decision.opened', 'decision', 9702, '发起决策：选择校准数据的安全交付方式', NOW() - INTERVAL 1 DAY - INTERVAL 6 HOUR),
(9916, 9403, 9002, 'helper', 'deliverable.submitted', 'deliverable', 9751, '提交交付物：目标 CMOS 传感器 INT8 校准集 v1（2000 帧）', NOW() - INTERVAL 1 DAY - INTERVAL 2 HOUR),
(9917, 9403, 9002, 'helper', 'baton.passed', 'match', 9403, '校准样例和元数据已就绪，等你确认交付方式并运行 INT8 回归。', NOW() - INTERVAL 2 HOUR);

-- ---------------------------------------------------------------------
-- 8. Agent 长期记忆（7 条；kind 映射到后端允许的枚举值）
-- ---------------------------------------------------------------------

INSERT INTO nexus_agent_memories
(id, user_id, kind, title, content, tags, importance, pinned,
 status, source_type, sensitivity, share_policy, access_count,
 created_at, updated_at) VALUES
(9801, 9001, 'environment', '目标传感器域的成像特性',
 '目标 CMOS + 自研 ISP 的成像风格与公开数据集差异显著：tone mapping 偏暖、高ISO噪声呈块状。INT8 校准数据必须来自目标域。',
 '["edge-vision","int8"]', 8, 0, 'active', 'user', 'normal', 'private', 3,
 NOW() - INTERVAL 2 DAY, NOW() - INTERVAL 2 DAY),
(9802, 9001, 'preference', '协作偏好：先小样本验证再全量交付',
 '涉及数据交付的协作，优先接受先交小样本（500 帧级）验证管线、再全量交付的节奏，降低双方风险。',
 '["collaboration"]', 6, 0, 'active', 'user', 'normal', 'private', 1,
 NOW() - INTERVAL 5 DAY, NOW() - INTERVAL 5 DAY),
(9803, 9002, 'workflow', '传感器数据脱敏四步流程',
 '1) 人脸/车牌模糊 + 5% 人工抽检；2) 元数据剔除 GPS 与精确时间戳；3) 文件名哈希化；4) 附 SHA-256 清单与许可说明。',
 '["data-anonymization"]', 9, 1, 'active', 'user', 'normal', 'private', 5,
 NOW() - INTERVAL 5 DAY, NOW() - INTERVAL 4 DAY),
(9804, 9002, 'constraint', '校内数据共享需签署使用范围协议',
 '实验室规定：所有对外共享数据必须附带书面使用范围说明，明确禁止二次分发，接收方需签字确认。',
 '["policy","dataset"]', 8, 0, 'active', 'user', 'normal', 'private', 2,
 NOW() - INTERVAL 6 DAY, NOW() - INTERVAL 6 DAY),
(9805, 9003, 'outcome', 'LoRA 合并的 dtype 陷阱',
 'merge_and_unload 时基座必须用与训练一致的 dtype 加载（bf16 训就用 bf16 合），fp16 合并会导致量化后输出乱码。',
 '["llm-finetuning","lesson-learned"]', 9, 0, 'active', 'user', 'normal', 'private', 4,
 NOW() - INTERVAL 23 HOUR, NOW() - INTERVAL 23 HOUR),
(9806, 9004, 'constraint', '实验室 GPU 服务器维护窗口',
 '每周日 02:00-06:00 是共享 GPU 服务器维护窗口，长任务需避开或提前报备。',
 '["gpu-cluster","policy"]', 5, 0, 'active', 'user', 'normal', 'private', 0,
 NOW() - INTERVAL 12 HOUR, NOW() - INTERVAL 12 HOUR),
(9807, 9005, 'preference', '设计评审关注点',
 '做界面走查时优先看：8px 网格一致性、对比度（WCAG AA）、空状态与加载态是否设计过。',
 '["design-review"]', 6, 0, 'active', 'user', 'normal', 'private', 1,
 NOW() - INTERVAL 3 DAY, NOW() - INTERVAL 3 DAY);

-- ---------------------------------------------------------------------
-- 9. Skill / MCP 资源库（owner 9000 nexus_resources_demo；文案同 fixtures/resource-demo.json）
--    description 带【MOCK 演示数据】前缀，前端会显示 DEMO 角标。
-- ---------------------------------------------------------------------

INSERT INTO nexus_catalog_resources
(id, kind, name, category, summary, description, source_url, install_command, endpoint, transport, auth_type, owner_id, created_at, updated_at) VALUES
(9351, 'skill', '代码审查助手 · 演示', '开发工具',
 '检查变更中的边界条件、异常处理与可维护性，输出按优先级排列的审查建议。',
 '【MOCK 演示数据】仅用于展示与交互验证，项目地址、服务和命令均为占位示例，不可直接安装或连接。\n\n适用场景：提交前自查、Pull Request 审阅。\n使用步骤：提供变更说明与 diff，梳理功能影响，再按正确性、权限边界和测试覆盖输出建议。',
 'https://example.invalid/nexus-demo/skill/code-review', '# 演示安装命令，请替换为真实仓库\n# npx skills add owner/repo --skill code-review', '', '', '', 9000, NOW() - INTERVAL 6 DAY, NOW() - INTERVAL 6 DAY),
(9352, 'skill', 'Vue 组件设计 · 演示', '开发工具',
 '从界面需求拆分组件，整理 Props、事件与状态，让页面结构更清晰。',
 '【MOCK 演示数据】仅用于展示与交互验证，项目地址、服务和命令均为占位示例，不可直接安装或连接。\n\n适用场景：Vue 页面开发和组件拆分。\n交付内容：组件职责表、数据流说明、交互状态清单与可访问性检查项。',
 'https://example.invalid/nexus-demo/skill/vue-components', '# 演示安装命令，请替换为真实仓库\n# npx skills add owner/repo --skill vue-components', '', '', '', 9000, NOW() - INTERVAL 6 DAY, NOW() - INTERVAL 6 DAY),
(9353, 'skill', '界面体验走查 · 演示', '设计体验',
 '覆盖明暗主题、移动端布局、表单反馈与键盘操作，整理可执行的体验改进清单。',
 '【MOCK 演示数据】仅用于展示与交互验证，项目地址、服务和命令均为占位示例，不可直接安装或连接。\n\n适用场景：页面上线前验收。\n检查内容：文字层级、颜色对比、空状态、加载与错误提示、320px 小屏幕和键盘焦点。',
 'https://example.invalid/nexus-demo/skill/design-review', '# 演示工具包：从项目文档获取 SKILL.md 后放入客户端技能目录。', '', '', '', 9000, NOW() - INTERVAL 5 DAY, NOW() - INTERVAL 5 DAY),
(9354, 'skill', '数据清洗工作流 · 演示', '数据处理',
 '识别重复记录、缺失字段与格式差异，生成清洗方案和数据质量报告。',
 '【MOCK 演示数据】仅用于展示与交互验证，项目地址、服务和命令均为占位示例，不可直接安装或连接。\n\n适用场景：CSV 整理与实验数据预处理。\n使用步骤：先分析字段与缺失分布，再确认清洗规则，最后对比处理前后的记录数。',
 'https://example.invalid/nexus-demo/skill/dataset-cleaning', '# 演示安装命令，请替换为真实仓库\n# npx skills add owner/repo --skill dataset-cleaning', '', '', '', 9000, NOW() - INTERVAL 5 DAY, NOW() - INTERVAL 5 DAY),
(9355, 'skill', '论文阅读笔记 · 演示', '学习研究',
 '按研究问题、方法、实验结果与局限整理文献，帮助建立可追溯的阅读笔记。',
 '【MOCK 演示数据】仅用于展示与交互验证，项目地址、服务和命令均为占位示例，不可直接安装或连接。\n\n适用场景：文献阅读和组会准备。\n交付内容：论文摘要、方法图解要点、实验对照、疑问列表与原文页码。',
 'https://example.invalid/nexus-demo/skill/paper-reading', '# 演示工具包：从项目文档获取论文阅读模板和 SKILL.md。', '', '', '', 9000, NOW() - INTERVAL 4 DAY, NOW() - INTERVAL 4 DAY),
(9356, 'skill', '会议行动清单 · 演示', '效率工具',
 '从会议记录中提取决定、负责人和截止时间，把讨论整理成可以跟进的任务。',
 '【MOCK 演示数据】仅用于展示与交互验证，项目地址、服务和命令均为占位示例，不可直接安装或连接。\n\n适用场景：项目周会、组会和课程协作。\n使用步骤：提供会议记录，区分明确决定与待确认事项，核对负责人后输出行动清单。',
 'https://example.invalid/nexus-demo/skill/meeting-actions', '# 演示安装命令，请替换为真实仓库\n# npx skills add owner/repo --skill meeting-actions', '', '', '', 9000, NOW() - INTERVAL 4 DAY, NOW() - INTERVAL 4 DAY),
(9357, 'mcp', '校园文献索引 · 演示', '学习研究',
 '检索文献标题、作者与摘要，为阅读和引用整理提供结构化结果。',
 '【MOCK 演示数据】仅用于展示与交互验证，项目地址、服务和命令均为占位示例，不可直接安装或连接。\n\n示例工具：search_papers、get_paper_metadata。\n鉴权示例：从服务管理者处获取个人 Token，在客户端首次连接时填写。',
 'https://example.invalid/nexus-demo/mcp/campus-library', '', 'https://example.invalid/nexus-demo/campus-library/mcp', 'streamable-http', 'bearer', 9000, NOW() - INTERVAL 3 DAY, NOW() - INTERVAL 3 DAY),
(9358, 'mcp', '项目仓库工具 · 演示', '开发工具',
 '展示仓库、Issue 与代码变更的查询场景，方便组织开发协作上下文。',
 '【MOCK 演示数据】仅用于展示与交互验证，项目地址、服务和命令均为占位示例，不可直接安装或连接。\n\n示例工具：list_repositories、search_issues、get_change_summary。\n鉴权示例：使用只读范围的个人 Token。实际权限由目标服务管理。',
 'https://example.invalid/nexus-demo/mcp/project-repository', '', 'https://example.invalid/nexus-demo/project-repository/mcp', 'streamable-http', 'bearer', 9000, NOW() - INTERVAL 3 DAY, NOW() - INTERVAL 3 DAY),
(9359, 'mcp', '实验数据目录 · 演示', '数据处理',
 '按实验项目和数据类型检索数据集元信息，查看字段、版本与使用说明。',
 '【MOCK 演示数据】仅用于展示与交互验证，项目地址、服务和命令均为占位示例，不可直接安装或连接。\n\n示例工具：search_datasets、get_dataset_schema。\n这里演示仅返回数据集目录和元数据的公开只读接口。',
 'https://example.invalid/nexus-demo/mcp/dataset-catalog', '', 'https://example.invalid/nexus-demo/dataset-catalog/mcp', 'streamable-http', 'none', 9000, NOW() - INTERVAL 2 DAY, NOW() - INTERVAL 2 DAY),
(9360, 'mcp', '设计素材检索 · 演示', '设计体验',
 '统一查询图标、配色与组件规范，给界面设计提供一致的资源入口。',
 '【MOCK 演示数据】仅用于展示与交互验证，项目地址、服务和命令均为占位示例，不可直接安装或连接。\n\n示例工具：find_icons、get_color_tokens、get_component_spec。\n展示需要 Token 的 SSE 连接方式，便于检查旧版服务接入配置。',
 'https://example.invalid/nexus-demo/mcp/design-assets', '', 'https://example.invalid/nexus-demo/design-assets/sse', 'sse', 'bearer', 9000, NOW() - INTERVAL 2 DAY, NOW() - INTERVAL 2 DAY),
(9361, 'mcp', '本地笔记检索 · 演示', '效率工具',
 '演示通过本地 stdio 服务检索 Markdown 笔记，适合个人知识库场景。',
 '【MOCK 演示数据】仅用于展示与交互验证，项目地址、服务和命令均为占位示例，不可直接安装或连接。\n\n示例工具：search_notes、read_note。\n该条目演示本地 stdio 传输；如实际工具需要 API Key，请通过客户端环境变量配置。',
 'https://example.invalid/nexus-demo/mcp/local-notes', '# 演示启动方式，请替换为实际可用脚本\n# python /path/to/notes_mcp_server.py', '', 'stdio', 'none', 9000, NOW() - INTERVAL 1 DAY, NOW() - INTERVAL 1 DAY),
(9362, 'mcp', '校园活动信息 · 演示', '其他',
 '按时间和主题查询活动信息，展示无需 Token 的公开 MCP 服务接入方式。',
 '【MOCK 演示数据】仅用于展示与交互验证，项目地址、服务和命令均为占位示例，不可直接安装或连接。\n\n示例工具：list_events、get_event_detail。\n展示公开 SSE 接口的配置形式。实际服务应单独确认数据来源与更新频率。',
 'https://example.invalid/nexus-demo/mcp/campus-events', '', 'https://example.invalid/nexus-demo/campus-events/sse', 'sse', 'none', 9000, NOW() - INTERVAL 1 DAY, NOW() - INTERVAL 1 DAY);

-- ---------------------------------------------------------------------
-- 10. 验证输出
-- ---------------------------------------------------------------------

SELECT 'discussions'  AS item, COUNT(*) AS demo_rows FROM discussions  WHERE id BETWEEN 9101 AND 9108
UNION ALL SELECT 'posts',           COUNT(*) FROM posts               WHERE id BETWEEN 9201 AND 9224
UNION ALL SELECT 'help_requests',   COUNT(*) FROM nexus_help_requests WHERE id BETWEEN 9301 AND 9306
UNION ALL SELECT 'matches',         COUNT(*) FROM nexus_help_matches  WHERE id IN (9401, 9402, 9403)
UNION ALL SELECT 'match_tasks',     COUNT(*) FROM nexus_match_tasks   WHERE id BETWEEN 9601 AND 9606
UNION ALL SELECT 'match_messages',  COUNT(*) FROM nexus_help_match_messages WHERE id IN (9501, 9502, 9503, 9504)
UNION ALL SELECT 'match_decisions', COUNT(*) FROM nexus_match_decisions WHERE id IN (9701, 9702)
UNION ALL SELECT 'match_deliverables', COUNT(*) FROM nexus_match_deliverables WHERE id = 9751
UNION ALL SELECT 'match_events',    COUNT(*) FROM nexus_match_events  WHERE id BETWEEN 9901 AND 9917
UNION ALL SELECT 'memories',        COUNT(*) FROM nexus_agent_memories WHERE id BETWEEN 9801 AND 9807
UNION ALL SELECT 'users',           COUNT(*) FROM users               WHERE id BETWEEN 9000 AND 9005
UNION ALL SELECT 'capabilities',    COUNT(*) FROM nexus_user_capabilities WHERE id BETWEEN 9001 AND 9015
UNION ALL SELECT 'resources',       COUNT(*) FROM nexus_catalog_resources WHERE id BETWEEN 9351 AND 9362;
