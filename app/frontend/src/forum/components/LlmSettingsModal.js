import app from 'flarum/forum/app';
import Modal from 'flarum/common/components/Modal';
import Button from 'flarum/common/components/Button';
import Switch from 'flarum/common/components/Switch';
import Stream from 'flarum/common/utils/Stream';

export default class LlmSettingsModal extends Modal {
  oninit(vnode) {
    super.oninit(vnode);

    this.provider = Stream('builtin');
    this.baseUrl = Stream('');
    this.chatModel = Stream('');
    this.responsesModel = Stream('');
    this.apiKey = Stream('');
    this.supportsChatCompletions = true;
    this.supportsResponses = true;
    this.apiKeySet = false;
    this.apiKeyPreview = '';
    this.confirmed = false;
    this.loadingSettings = true;

    this.loadSettings();
  }

  className() {
    return 'NexusLlmSettingsModal Modal--small';
  }

  title() {
    return app.translator.trans('nexus-forum.forum.settings.llm_heading');
  }

  content() {
    const isBuiltin = this.provider() === 'builtin';

    return (
      <div className="Modal-body">
        <div className="Form">
          <p className="helpText">{app.translator.trans('nexus-forum.forum.settings.llm_help')}</p>

          {this.loadingSettings ? (
            <p className="helpText">{app.translator.trans('core.lib.loading_indicator.accessible_label')}</p>
          ) : (
            [
              <div className="Form-group">
                <label>{app.translator.trans('nexus-forum.forum.settings.provider_label')}</label>
                <select
                  className="FormControl"
                  value={this.provider()}
                  onchange={(event) => {
                    this.provider(event.target.value);
                  }}
                  disabled={this.loading}
                >
                  <option value="builtin">{app.translator.trans('nexus-forum.forum.settings.provider_builtin')}</option>
                  <option value="openai-compatible">{app.translator.trans('nexus-forum.forum.settings.provider_chat')}</option>
                  <option value="openai-responses-compatible">{app.translator.trans('nexus-forum.forum.settings.provider_responses')}</option>
                </select>
                {isBuiltin && <p className="helpText">{app.translator.trans('nexus-forum.forum.settings.builtin_note')}</p>}
              </div>,

              <div className="Form-group">
                <label>{app.translator.trans('nexus-forum.forum.settings.base_url_label')}</label>
                <input
                  className="FormControl"
                  name="baseUrl"
                  type="url"
                  placeholder={app.translator.trans('nexus-forum.forum.settings.base_url_placeholder')}
                  bidi={this.baseUrl}
                  disabled={this.loading || isBuiltin}
                />
              </div>,

              <div className="Form-group">
                <label>{app.translator.trans('nexus-forum.forum.settings.chat_model_label')}</label>
                <input className="FormControl" name="chatModel" type="text" bidi={this.chatModel} disabled={this.loading || isBuiltin} />
              </div>,

              <div className="Form-group">
                <label>{app.translator.trans('nexus-forum.forum.settings.responses_model_label')}</label>
                <input
                  className="FormControl"
                  name="responsesModel"
                  type="text"
                  bidi={this.responsesModel}
                  disabled={this.loading || isBuiltin}
                />
              </div>,

              <div className="Form-group">
                <label>{app.translator.trans('nexus-forum.forum.settings.api_key_label')}</label>
                <input
                  className="FormControl"
                  name="apiKey"
                  type="password"
                  autocomplete="new-password"
                  placeholder={app.translator.trans('nexus-forum.forum.settings.api_key_placeholder')}
                  bidi={this.apiKey}
                  disabled={this.loading || isBuiltin}
                />
                <p className="helpText">
                  {this.apiKeySet
                    ? app.translator.trans('nexus-forum.forum.settings.api_key_set', { preview: this.apiKeyPreview })
                    : app.translator.trans('nexus-forum.forum.settings.api_key_not_set')}
                </p>
              </div>,

              <div className="Form-group">
                <Switch
                  state={this.supportsChatCompletions}
                  onchange={(value) => {
                    this.supportsChatCompletions = value;
                  }}
                  disabled={this.loading || isBuiltin}
                >
                  {app.translator.trans('nexus-forum.forum.settings.supports_chat_label')}
                </Switch>
              </div>,

              <div className="Form-group">
                <Switch
                  state={this.supportsResponses}
                  onchange={(value) => {
                    this.supportsResponses = value;
                  }}
                  disabled={this.loading || isBuiltin}
                >
                  {app.translator.trans('nexus-forum.forum.settings.supports_responses_label')}
                </Switch>
              </div>,

              <div className="Form-group">
                <label className="checkbox">
                  <input
                    type="checkbox"
                    checked={this.confirmed}
                    disabled={this.loading}
                    onchange={(event) => {
                      this.confirmed = event.target.checked;
                      m.redraw();
                    }}
                  />{' '}
                  {app.translator.trans('nexus-forum.forum.settings.confirmation_label')}
                </label>
              </div>,

              <div className="Form-group">
                <Button className="Button Button--primary Button--block" type="submit" loading={this.loading} disabled={!this.confirmed}>
                  {app.translator.trans('nexus-forum.forum.settings.submit_button')}
                </Button>
              </div>,
            ]
          )}
        </div>
      </div>
    );
  }

  loadSettings() {
    app
      .request({
        method: 'GET',
        url: `${app.forum.attribute('apiUrl')}/nexus/llm-settings`,
      })
      .then((response) => {
        this.applyAttributes(response.data.attributes || {});
      })
      .catch(() => {
        app.alerts.show({ type: 'error' }, app.translator.trans('nexus-forum.forum.settings.load_error'));
      })
      .then(() => {
        this.loadingSettings = false;
        m.redraw();
      });
  }

  applyAttributes(attributes) {
    this.provider(attributes.provider || 'builtin');
    this.baseUrl(attributes.baseUrl || '');
    this.chatModel(attributes.chatModel || '');
    this.responsesModel(attributes.responsesModel || '');
    this.supportsChatCompletions = attributes.supportsChatCompletions !== false;
    this.supportsResponses = attributes.supportsResponses !== false;
    this.apiKeySet = !!attributes.apiKeySet;
    this.apiKeyPreview = attributes.apiKeyPreview || '';
    this.apiKey('');
  }

  onsubmit(event) {
    event.preventDefault();

    if (!this.confirmed) return;

    this.loading = true;

    const attributes = {
      userConfirmed: true,
      provider: this.provider(),
      baseUrl: this.baseUrl(),
      chatModel: this.chatModel(),
      responsesModel: this.responsesModel(),
      supportsChatCompletions: this.supportsChatCompletions,
      supportsResponses: this.supportsResponses,
    };

    if (this.apiKey() !== '') {
      attributes.apiKey = this.apiKey();
    }

    app
      .request({
        method: 'PATCH',
        url: `${app.forum.attribute('apiUrl')}/nexus/llm-settings`,
        body: {
          data: {
            type: 'nexus-llm-settings',
            attributes,
          },
        },
        errorHandler: this.onerror.bind(this),
      })
      .then((response) => {
        this.applyAttributes(response.data.attributes || {});
        app.alerts.show({ type: 'success' }, app.translator.trans('nexus-forum.forum.settings.saved_message'));
        this.hide();
      })
      .catch(() => {})
      .then(this.loaded.bind(this));
  }
}
