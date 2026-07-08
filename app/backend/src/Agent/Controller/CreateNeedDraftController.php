<?php

namespace Nexus\Forum\Api\Controller;

use Flarum\Api\Controller\AbstractShowController;
use Flarum\Http\RequestUtil;
use Illuminate\Support\Arr;
use Nexus\Forum\Agent\Serializer\NeedDraftSerializer;
use Nexus\Forum\Agent\Service\NeedDraftGenerator;
use Psr\Http\Message\ServerRequestInterface;
use Tobscure\JsonApi\Document;

class CreateNeedDraftController extends AbstractShowController
{
    public $serializer = NeedDraftSerializer::class;

    private NeedDraftGenerator $generator;

    public function __construct(NeedDraftGenerator $generator)
    {
        $this->generator = $generator;
    }

    protected function data(ServerRequestInterface $request, Document $document)
    {
        $actor = RequestUtil::getActor($request);
        $actor->assertRegistered();

        $attributes = Arr::get($request->getParsedBody(), 'data.attributes', []);

        return $this->generator->generate($attributes);
    }
}
