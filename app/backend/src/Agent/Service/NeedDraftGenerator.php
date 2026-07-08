<?php

namespace Nexus\Forum\Service;

use Flarum\Tags\Tag;

class NeedDraftGenerator
{
    public function generate(array $attributes): array
    {
        $rawNeed = NexusPayload::string($attributes, 'rawUserNeed', 4000, true);
        $requestedIntent = NexusPayload::oneOf(
            $attributes,
            'intent',
            ['auto', 'direct-answer', 'help', 'team', 'friend'],
            'auto'
        );
        $locationHint = NexusPayload::string($attributes, 'locationHint', 255, false)
            ?: $this->extractLocationHint($rawNeed);

        $intent = $requestedIntent === 'auto' ? $this->classifyIntent($rawNeed) : $requestedIntent;
        $urgency = $this->detectUrgency($rawNeed);
        $neededLabels = $this->suggestLabels($rawNeed, $intent);
        $tagSlug = $this->tagSlugForIntent($intent);
        $shouldEnterForum = $intent !== 'direct-answer';
        $title = $this->titleFor($rawNeed, $intent);
        $summary = $this->summaryFor($rawNeed, $intent);
        $content = $this->contentFor($rawNeed, $intent, $neededLabels, $locationHint, $urgency);

        return [
            'id' => 'draft-'.substr(hash('sha256', $intent.'|'.$rawNeed), 0, 16),
            'rawUserNeed' => $rawNeed,
            'intent' => $intent,
            'shouldEnterForum' => $shouldEnterForum,
            'requiresUserConfirmation' => $shouldEnterForum,
            'targetTagSlug' => $tagSlug,
            'targetTagId' => $this->tagId($tagSlug),
            'categoryLabel' => $intent === 'help' ? 'help' : $intent,
            'title' => $title,
            'summary' => $summary,
            'content' => $content,
            'neededLabels' => $neededLabels,
            'urgency' => $urgency,
            'locationHint' => $locationHint,
            'meetingSafetyState' => $shouldEnterForum ? 'public_place_suggested' : 'not_arranged',
            'suggestedSearchQueries' => $this->suggestedSearchQueries($rawNeed, $neededLabels, $intent),
            'labelReuse' => $this->labelReuseGuidance($neededLabels, $intent),
            'discoveryPlan' => $this->discoveryPlan($intent, $neededLabels, $rawNeed, $locationHint),
            'publish' => $this->publishShape($intent, $tagSlug, $title, $summary, $content, $neededLabels, $urgency, $locationHint),
            'nextStep' => $this->nextStep($intent),
            'safetyNotes' => $this->safetyNotes($intent),
        ];
    }

    private function classifyIntent(string $rawNeed): string
    {
        $text = mb_strtolower($rawNeed);

        if ($this->containsAny($text, [
            '组队', '组个队', '队友', '找队友', '征队友', '队伍', '招募', '招人', '合作',
            '比赛', '竞赛', '参赛', '训练赛', '学习小组', '创新创业', '搭班子', '黑客松',
            '数学建模', '挑战杯', '创业', '科研合作',
            'team', 'teammate', 'team up', 'project teammate', 'project partner',
            'competition', 'hackathon',
        ])) {
            return 'team';
        }

        if ($this->containsAny($text, [
            '交友', '交朋友', '朋友', '同频', '同好', '认识', '聊天', '找对象', '破冰',
            '搭子', '饭搭子', '约饭', '吃饭搭子', '学习搭子', '运动搭子', '活动搭子',
            'citywalk', '看展', '看电影', '社交',
            'friend', 'friends', 'date', 'dating', 'meet people', 'hang out',
        ])) {
            return 'friend';
        }

        if ($this->containsAny($text, [
            '教程', '写一份', '帮我写', '生成', '总结', '解释', '代码', '编程', '报错', 'ppt', '文档', '论文', '作业',
            'how to', 'how do i', 'how can i', 'explain', 'write', 'summarize', 'code',
        ])) {
            return 'direct-answer';
        }

        $looksLikeQuestion = $this->containsAny($text, [
            '怎么', '如何', '怎么办', '怎么做', '怎么弄',
        ]);
        $looksPhysical = $this->containsAny($text, [
            '我在', '人在', '位于', '地点', '位置', '附近', '找人', '有没有人', '能不能', '可不可以',
            '线下', '当面', '现场', '送', '借', '拿', '需要人', 'nearby', 'in person',
        ]);

        if ($looksLikeQuestion && ! $looksPhysical) {
            return 'direct-answer';
        }

        if ($this->containsAny($text, [
            '借伞', '送伞', '伞', '下雨', '暴雨', '维修', '修电脑', '电脑维修', '装机',
            '开不了机', '蓝屏', '打印', '搬东西', '搬家', '丢了', '遗失', '捡到',
            '找路', '报修', '校园卡', '设备', '志愿者', '摄影', '拍照', '主持',
            '现场', '线下', '当面', '附近', '帮我拿', '帮我送', '帮忙送', '帮我带',
            '代拿', '代取', '取快递', '拿快递', '带饭', '需要人',
            'umbrella', 'repair', 'fix', 'broken', 'lost', 'printer', 'camera', 'photo', 'nearby', 'in person',
        ])) {
            return 'help';
        }

        return 'help';
    }

    private function detectUrgency(string $rawNeed): string
    {
        $text = mb_strtolower($rawNeed);

        if ($this->containsAny($text, [
            '急', '紧急', '马上', '立刻', '今晚', '赶时间', '截止', 'ddl', 'deadline', 'urgent',
        ])) {
            return 'urgent';
        }

        if ($this->containsAny($text, [
            '今天', '下午', '明天', '尽快', '下雨', '快点', 'soon', 'today', 'tomorrow',
        ])) {
            return 'soon';
        }

        return 'normal';
    }

    private function suggestLabels(string $rawNeed, string $intent): array
    {
        if ($intent === 'direct-answer') {
            return ['direct-answer'];
        }

        $text = mb_strtolower($rawNeed);
        $labels = [];

        foreach ([
            'umbrella-help' => ['借伞', '送伞', '伞', '雨', '下雨', '暴雨', 'umbrella', 'rain'],
            'computer-repair' => ['电脑', '笔记本', '开不了机', '蓝屏', '装机', '系统', '重装系统', '维修电脑', '修电脑', '电脑维修', 'repair', 'laptop', 'computer'],
            'printer-help' => ['打印', '打印机', '复印', 'printer'],
            'moving-help' => ['搬', '搬东西', '搬家', '重物', '行李', 'move'],
            'lost-and-found' => ['丢了', '遗失', '捡到', '失物', 'lost'],
            'campus-process' => ['校园卡', '报修', '办公室', '流程', '手续', '盖章'],
            'navigation-help' => ['找路', '教室', '迷路', '路线', '导航'],
            'photography' => ['摄影', '拍照', '相机', 'camera', 'photo'],
            'team-up' => ['组队', '组个队', '队友', '找队友', '征队友', '队伍', '比赛', '竞赛', '参赛', '项目', '招募', '招人', '学习小组', '黑客松', '数学建模', '挑战杯', 'team', 'teammate', 'hackathon'],
            'social-match' => ['交友', '交朋友', '朋友', '同频', '同好', '聊天', '找对象', '搭子', '饭搭子', '约饭', '吃饭搭子', '学习搭子', '运动搭子', '活动搭子', '看电影', '看展', 'friend', 'date', 'hang out'],
            'ai' => ['ai', 'agent', '大模型', 'llm'],
            'frontend' => ['前端', 'react', 'vue', 'ui'],
            'backend' => ['后端', 'api', 'php', 'node', 'python'],
            'design' => ['设计', '海报', 'figma', 'poster'],
        ] as $label => $keywords) {
            if ($this->containsAny($text, $keywords)) {
                $labels[$label] = $label;
            }
        }

        if (! $labels) {
            $fallback = [
                'help' => 'campus-help',
                'team' => 'team-up',
                'friend' => 'social-match',
                'direct-answer' => 'direct-answer',
            ][$intent] ?? 'campus-help';
            $labels[$fallback] = $fallback;
        }

        return array_values(array_slice($labels, 0, 8));
    }

    private function extractLocationHint(string $rawNeed): ?string
    {
        foreach ([
            '/(?:我(?:现在)?在|人在|当前位置在|现在在|位于|地点[:：]?|位置[:：]?)([^，。！？；,.!?;\n]{2,40})/u',
            '/在([^，。！？；,.!?;\n]{2,40}?)(?=(?:需要|想|求|没|没有|等|找|帮|可不可以|能不能|坏|开不了|打不开|下雨|$))/u',
            '/\b(?:at|near)\s+([^,.!?;\n]{2,60})/iu',
        ] as $pattern) {
            if (preg_match($pattern, $rawNeed, $matches)) {
                $location = $this->cleanLocationHint($matches[1]);

                if ($location !== null) {
                    return $location;
                }
            }
        }

        return null;
    }

    private function cleanLocationHint(string $location): ?string
    {
        $location = preg_split('/[，。！？；,.!?;\n]/u', trim($location), 2)[0] ?? $location;
        $location = preg_split(
            '/(?:需要|想|希望|求|帮|能不能|可不可以|有没有|没有|没带|没|坏了|开不了|打不开|丢了|下雨|要|找|等|\s+and\s+|\s+but\s+|\s+because\s+|\s+with\s+|\s+where\s+|\s+while\s+)/iu',
            $location,
            2
        )[0] ?? $location;
        $location = trim($location);
        $location = preg_replace('/^[,.;:!?，。；：！？\s]+|[,.;:!?，。；：！？\s]+$/u', '', $location) ?? $location;

        if ($location === '' || mb_strlen($location) < 2) {
            return null;
        }

        return mb_substr($location, 0, 80);
    }

    private function titleFor(string $rawNeed, string $intent): string
    {
        $prefix = [
            'help' => 'Help',
            'team' => 'Team',
            'friend' => 'Connect',
            'direct-answer' => 'Direct answer',
        ][$intent] ?? 'Nexus';

        $snippet = preg_replace('/\s+/u', ' ', trim($rawNeed));
        $snippet = mb_substr($snippet, 0, 56);

        return mb_substr($prefix.': '.$snippet, 0, 120);
    }

    private function summaryFor(string $rawNeed, string $intent): string
    {
        $summary = trim($rawNeed);

        if ($intent === 'direct-answer') {
            return 'This looks solvable by the user agent without posting to the forum: '.$summary;
        }

        return mb_substr($summary, 0, 600);
    }

    private function contentFor(string $rawNeed, string $intent, array $neededLabels, ?string $locationHint, string $urgency): string
    {
        $lines = [
            'Nexus agent draft based on the user need:',
            '',
            trim($rawNeed),
        ];

        if ($neededLabels) {
            $lines[] = '';
            $lines[] = 'Suggested capability labels: #'.implode(' #', $neededLabels);
        }

        if ($locationHint) {
            $lines[] = 'Coarse location hint: '.$locationHint;
        }

        if ($urgency !== 'normal') {
            $lines[] = 'Urgency: '.$urgency;
        }

        if ($intent !== 'direct-answer') {
            $lines[] = '';
            $lines[] = 'Safety: confirm with the user before publishing. Prefer a public, visible, easy-to-find meeting place for offline help.';
        }

        return implode("\n", $lines);
    }

    private function tagSlugForIntent(string $intent): ?string
    {
        return [
            'help' => 'help',
            'team' => 'team',
            'friend' => 'friend',
        ][$intent] ?? null;
    }

    private function tagId(?string $slug): ?int
    {
        if (! $slug) {
            return null;
        }

        $tag = Tag::where('slug', $slug)->first();

        return $tag ? (int) $tag->id : null;
    }

    private function suggestedSearchQueries(string $rawNeed, array $labels, string $intent): array
    {
        $queries = $labels;
        $queries[] = $intent;
        $queries[] = mb_substr(trim($rawNeed), 0, 80);

        return array_values(array_unique(array_filter($queries)));
    }

    private function labelReuseGuidance(array $labels, string $intent): array
    {
        $searches = array_map(function (string $label): array {
            return [
                'label' => $label,
                'method' => 'GET',
                'endpoint' => '/api/nexus/capability-labels',
                'query' => [
                    'inname' => $label,
                    'sort' => 'popular',
                    'page[limit]' => 10,
                ],
                'matchPolicy' => [
                    'preferExactExistingLabel' => true,
                    'preferActiveHelpers' => true,
                    'minimumUsefulHelperCount' => 1,
                    'acceptCloseMatchWhenUserMeaningMatches' => true,
                ],
                'writesState' => false,
            ];
        }, $labels);

        return [
            'readOnly' => true,
            'intent' => $intent,
            'strategy' => 'Search the public capability-label directory first. Reuse an established label with helpers before inventing a near-duplicate label.',
            'proposedLabels' => array_values($labels),
            'searches' => array_values($searches),
            'rules' => [
                'Prefer an exact existing label when helperCount is greater than 0.',
                'Prefer a close existing label over a new synonym when the user meaning is the same.',
                'Keep labels short, stable, and easy for humans to read.',
                'Only keep a new label after checking the label directory, capabilities, forum discussions, and open help requests.',
            ],
            'publishBodyFields' => [
                'helpRequestNeededLabels' => 'data.attributes.neededLabels[]',
                'capabilityProfileLabel' => 'data.attributes.capabilities[].label',
            ],
            'fallback' => 'If no useful existing label exists, keep the clearest proposed label and use it consistently in help requests, capability profiles, and searches.',
        ];
    }

    private function discoveryPlan(string $intent, array $labels, string $rawNeed, ?string $locationHint): array
    {
        $queries = $this->suggestedSearchQueries($rawNeed, $labels, $intent);
        $label = $labels[0] ?? '<label>';
        $keyword = $queries[0] ?? mb_substr(trim($rawNeed), 0, 80);
        $beforePublishing = $intent !== 'direct-answer';

        $plan = [
            'readOnly' => true,
            'beforePublishing' => $beforePublishing,
            'goal' => 'Find existing labels, helpers, discussions, and open help requests before creating new public content.',
            'queries' => $queries,
            'locationHint' => $locationHint,
            'steps' => [
                [
                    'name' => 'reuse_existing_labels',
                    'method' => 'GET',
                    'endpoint' => '/api/nexus/capability-labels',
                    'query' => [
                        'inname' => $keyword,
                        'sort' => 'popular',
                        'page[limit]' => 10,
                    ],
                    'why' => 'Reuse established community capability labels instead of inventing near-duplicates.',
                    'requiredBeforePublish' => $beforePublishing,
                    'writesState' => false,
                ],
                [
                    'name' => 'find_capable_helpers',
                    'method' => 'GET',
                    'endpoint' => '/api/nexus/capabilities',
                    'query' => [
                        'filter[label]' => $label,
                        'page[limit]' => 10,
                    ],
                    'why' => 'Check whether an existing public helper profile can satisfy the need before posting.',
                    'requiredBeforePublish' => $intent === 'help',
                    'writesState' => false,
                ],
                [
                    'name' => 'search_forum_discussions',
                    'method' => 'GET',
                    'endpoint' => '/api/nexus/forum/discussions',
                    'query' => [
                        'q' => $keyword,
                        'include' => 'user,tags,firstPost',
                        'page[limit]' => 10,
                    ],
                    'why' => 'Find existing public answers, related posts, or active coordination threads before creating a duplicate discussion.',
                    'requiredBeforePublish' => $beforePublishing,
                    'writesState' => false,
                ],
                [
                    'name' => 'search_open_help_requests',
                    'method' => 'GET',
                    'endpoint' => '/api/nexus/help-requests',
                    'query' => [
                        'filter[status]' => 'open',
                        'filter[label]' => $label,
                        'page[limit]' => 10,
                    ],
                    'why' => 'Avoid duplicating an already-open public help request with a compatible label.',
                    'requiredBeforePublish' => $intent === 'help',
                    'writesState' => false,
                ],
                [
                    'name' => 'recover_own_open_requests',
                    'method' => 'GET',
                    'endpoint' => '/api/nexus/me/help-requests',
                    'query' => [
                        'filter[status]' => 'open',
                        'include' => 'discussion,matches,dispatches',
                        'page[limit]' => 10,
                    ],
                    'why' => 'Check whether the authenticated user already has an open related request that should be resumed instead of reposted.',
                    'requiredBeforePublish' => $intent === 'help',
                    'writesState' => false,
                ],
            ],
        ];

        if ($intent === 'help') {
            $plan['candidateStepAfterHelpRequest'] = [
                'name' => 'rank_candidates_after_help_request_exists',
                'method' => 'GET',
                'endpoint' => '/api/nexus/help-requests/{id}/candidates',
                'when' => 'After a help request exists, use this read-only endpoint before dispatching or creating a match.',
                'writesState' => false,
            ];
        }

        return $plan;
    }

    private function publishShape(
        string $intent,
        ?string $tagSlug,
        string $title,
        string $summary,
        string $content,
        array $neededLabels,
        string $urgency,
        ?string $locationHint
    ): array {
        if ($intent === 'help') {
            return [
                'endpoint' => 'POST /api/nexus/help-requests',
                'jsonApiType' => 'nexus-help-requests',
                'setUserConfirmedTrueOnlyAfterUserApproves' => true,
                'body' => [
                    'data' => [
                        'type' => 'nexus-help-requests',
                        'attributes' => [
                            'userConfirmed' => false,
                            'title' => $title,
                            'summary' => $summary,
                            'content' => $content,
                            'categoryLabel' => 'help',
                            'neededLabels' => $neededLabels,
                            'urgency' => $urgency,
                            'locationHint' => $locationHint,
                            'meetingSafetyState' => 'public_place_suggested',
                            'agentContext' => [
                                'source' => 'need-draft',
                                'intent' => $intent,
                            ],
                        ],
                    ],
                ],
            ];
        }

        if (in_array($intent, ['team', 'friend'], true)) {
            return [
                'endpoint' => 'POST /api/nexus/forum/discussions',
                'jsonApiType' => 'discussions',
                'targetTagSlug' => $tagSlug,
                'targetTagId' => $this->tagId($tagSlug),
                'setUserConfirmedTrueOnlyAfterUserApproves' => true,
                'body' => [
                    'data' => [
                        'type' => 'discussions',
                        'attributes' => [
                            'userConfirmed' => false,
                            'title' => $title,
                            'content' => $content,
                            'tags' => $tagSlug ? [$tagSlug] : [],
                        ],
                    ],
                ],
            ];
        }

        return [
            'endpoint' => null,
            'jsonApiType' => null,
            'setUserConfirmedTrueOnlyAfterUserApproves' => false,
            'body' => null,
        ];
    }

    private function nextStep(string $intent): string
    {
        if ($intent === 'direct-answer') {
            return 'Answer the user directly. Search the forum only if the user asks for community input.';
        }

        if ($intent === 'help') {
            return 'Search discussions and capability labels, show candidate helpers if any, then ask the user to confirm before POST /api/nexus/help-requests.';
        }

        return 'Search related discussions and public capability labels, then ask the user to confirm before posting a Flarum discussion.';
    }

    private function safetyNotes(string $intent): array
    {
        if ($intent === 'direct-answer') {
            return ['No forum write is recommended for this draft.'];
        }

        return [
            'Do not publish until the user explicitly approves the exact title, content, labels, and location hint.',
            'Avoid precise private location or contact details in public posts.',
            'For offline coordination, prefer public and visible meeting places.',
        ];
    }

    private function containsAny(string $text, array $needles): bool
    {
        foreach ($needles as $needle) {
            if ($needle !== '' && mb_strpos($text, mb_strtolower($needle)) !== false) {
                return true;
            }
        }

        return false;
    }
}
