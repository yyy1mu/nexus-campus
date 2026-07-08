<?php

namespace Nexus\Forum\Api\Controller;

use Flarum\Api\Controller\AbstractCreateController;
use Illuminate\Support\Arr;
use Nexus\Forum\Help\Serializer\HelpRequestSerializer;
use Nexus\Forum\Help\Service\HelpRequestCreator;
use Psr\Http\Message\ServerRequestInterface;
use Tobscure\JsonApi\Document;

class CreateHelpRequestController extends AbstractCreateController
{
    public $serializer = HelpRequestSerializer::class;

    public $include = ['discussion', 'requester'];

    private HelpRequestCreator $creator;

    public function __construct(HelpRequestCreator $creator)
    {
        $this->creator = $creator;
    }

    protected function data(ServerRequestInterface $request, Document $document)
    {
        $attributes = Arr::get($request->getParsedBody(), 'data.attributes', []);
        $ipAddress = $request->getAttribute('ipAddress') ?: '0.0.0.0';

        return $this->creator->create(\Flarum\Http\RequestUtil::getActor($request), $attributes, $ipAddress);
    }
}
