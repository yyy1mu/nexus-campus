import app from 'flarum/forum/app';
import { extend } from 'flarum/common/extend';
import Button from 'flarum/common/components/Button';
import LinkButton from 'flarum/common/components/LinkButton';
import HeaderSecondary from 'flarum/forum/components/HeaderSecondary';
import SettingsPage from 'flarum/forum/components/SettingsPage';
import LlmSettingsModal from './components/LlmSettingsModal';

app.initializers.add('nexus-forum', () => {
  extend(HeaderSecondary.prototype, 'items', function (items) {
    items.add(
      'nexusAgentDocs',
      <LinkButton className="Button Button--link" icon="fas fa-book-open" href={app.forum.attribute('nexusDocsUrl') || '/docs/'} external={true}>
        {app.translator.trans('nexus-forum.forum.header.agent_docs_link')}
      </LinkButton>,
      25
    );
  });

  extend(SettingsPage.prototype, 'accountItems', function (items) {
    if (!app.session.user) return;

    items.add(
      'nexusLlmSettings',
      <Button className="Button" icon="fas fa-brain" onclick={() => app.modal.show(LlmSettingsModal)}>
        {app.translator.trans('nexus-forum.forum.settings.llm_button')}
      </Button>,
      80
    );
  });
});
