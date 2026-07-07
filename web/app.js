/* ContactCRM web dashboard — Google SSO + encrypted local data */

const GOOGLE_CLIENT_ID = window.CONTACTCRM_GOOGLE_CLIENT_ID ||
  'YOUR_GOOGLE_CLIENT_ID.apps.googleusercontent.com'; // set in config.js or replace here

const App = (() => {
  let user = null;         // {name, email, picture}
  let view = 'dashboard';
  let detailContactId = null;
  let activePipelineId = null; // null = default board
  let searchText = '';
  let categoryFilter = '';

  const $ = sel => document.querySelector(sel);
  const main = () => $('#main');
  const esc = s => String(s ?? '').replace(/[&<>"']/g, c =>
    ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));

  /* ============ AUTH ============ */

  function initGoogleSignIn() {
    if (!window.google?.accounts?.id) { setTimeout(initGoogleSignIn, 300); return; }
    google.accounts.id.initialize({
      client_id: GOOGLE_CLIENT_ID,
      callback: onGoogleCredential,
      auto_select: true,
    });
    google.accounts.id.renderButton($('#gsi-button'), {
      theme: 'outline', size: 'large', shape: 'pill', width: 280,
    });
  }

  function onGoogleCredential(response) {
    // Decode the JWT payload client-side for display identity only.
    // No server: the token is not stored or sent anywhere.
    const payload = JSON.parse(atob(response.credential.split('.')[1].replace(/-/g, '+').replace(/_/g, '/')));
    user = { name: payload.name, email: payload.email, picture: payload.picture };
    sessionStorage.setItem('contactcrm-user', JSON.stringify(user));
    enterApp();
  }

  function demoLogin() {
    user = { name: 'Local user', email: '', picture: null };
    sessionStorage.setItem('contactcrm-user', JSON.stringify(user));
    enterApp();
  }

  function signOut() {
    sessionStorage.removeItem('contactcrm-user');
    if (window.google?.accounts?.id) google.accounts.id.disableAutoSelect();
    location.reload();
  }

  async function enterApp() {
    await Store.load();
    $('#login-screen').classList.add('hidden');
    $('#app').classList.remove('hidden');
    if (user.picture) {
      $('#user-avatar').src = user.picture;
      $('#user-avatar').hidden = false;
    }
    $('#user-name').textContent = user.name;
    render();
  }

  /* ============ RENDER ROUTER ============ */

  function render() {
    document.querySelectorAll('.tab').forEach(t =>
      t.classList.toggle('active', t.dataset.view === view));
    const views = { dashboard, contacts, contactDetail, pipelines, call, reminders, settings };
    if (detailContactId && view === 'contacts') { contactDetail(); return; }
    (views[view] || dashboard)();
  }

  function go(v) { view = v; detailContactId = null; render(); }

  /* ============ DASHBOARD ============ */

  function dashboard() {
    const d = Store.data;
    const stages = Store.DEFAULT_STAGES;
    const counts = stages.map(s => [s, d.contacts.filter(c => c.stage === s).length]);
    const upcoming = Store.upcomingReminders().slice(0, 5);
    const recent = d.contacts
      .flatMap(c => c.activities.map(a => ({ ...a, contact: c })))
      .sort((a, b) => b.ts - a.ts).slice(0, 8);

    main().innerHTML = `
      <div class="hero">
        <h2>Welcome back${user.name ? ', ' + esc(user.name.split(' ')[0]) : ''}</h2>
        <p>${d.contacts.length} contact${d.contacts.length === 1 ? '' : 's'} · ${Store.upcomingReminders().length} open reminder${Store.upcomingReminders().length === 1 ? '' : 's'}</p>
      </div>

      <div class="stat-grid">
        ${counts.map(([s, n]) => `
          <div class="stat-tile">
            <div class="stat-value">${n}</div>
            <div class="stat-label">${esc(s)}</div>
          </div>`).join('')}
      </div>

      <div class="card">
        <h3>Upcoming reminders</h3>
        ${upcoming.length === 0 ? `<p class="row-sub">Nothing scheduled.</p>` :
          upcoming.map(r => {
            const c = d.contacts.find(c => c.id === r.contactId);
            return `
            <div class="list-row" data-open-contact="${r.contactId}">
              <div class="activity-icon">🔔</div>
              <div class="row-body">
                <div class="row-title">${esc(r.title)}</div>
                <div class="row-sub">${c ? esc(fullName(c)) + ' · ' : ''}${fmtDate(r.due)}</div>
              </div>
            </div>`;
          }).join('')}
      </div>

      <div class="card">
        <h3>Recent activity</h3>
        ${recent.length === 0 ? `<p class="row-sub">No activity logged yet.</p>` :
          recent.map(a => `
          <div class="activity-item">
            <div class="activity-icon">${activityIcon(a.type)}</div>
            <div class="row-body">
              <div class="row-sub" style="font-weight:600">${esc(fullName(a.contact))}</div>
              <div>${esc(a.summary)}</div>
              <div class="activity-time">${fmtDate(a.ts)}</div>
            </div>
          </div>`).join('')}
      </div>
    `;
    bindOpenContact();
  }

  /* ============ CONTACTS ============ */

  function contacts() {
    const d = Store.data;
    const filtered = d.contacts.filter(c => {
      const matchCat = !categoryFilter || c.category === categoryFilter;
      const q = searchText.toLowerCase();
      const matchQ = !q || fullName(c).toLowerCase().includes(q) ||
        (c.email || '').toLowerCase().includes(q) || (c.phone || '').includes(q);
      return matchCat && matchQ;
    }).sort((a, b) => fullName(a).localeCompare(fullName(b)));

    main().innerHTML = `
      <h2 class="section-title">Contacts</h2>
      <div class="toolbar">
        <input type="search" id="contact-search" placeholder="Search name, email, phone" value="${esc(searchText)}">
        <select id="category-filter">
          <option value="">All categories</option>
          ${Store.CATEGORIES.map(c => `<option ${categoryFilter === c ? 'selected' : ''}>${c}</option>`).join('')}
        </select>
        <button class="btn-primary" id="add-contact">+ Add</button>
      </div>
      <div class="card">
        ${filtered.length === 0 ? `
          <div class="empty-state"><div class="big">👥</div>No contacts yet. Add your first one.</div>` :
          filtered.map(c => `
          <div class="list-row" data-open-contact="${c.id}">
            ${avatarHTML(c)}
            <div class="row-body">
              <div class="row-title">${esc(fullName(c))}</div>
              <div class="row-sub">${esc(c.title || c.email || '')}</div>
            </div>
            ${c.phone ? `<button class="btn-ghost btn-small" data-queue="${c.id}" title="Add to call queue">＋📞</button>` : ''}
            <span class="chip">${esc(c.category)}</span>
          </div>`).join('')}
      </div>
    `;
    $('#contact-search').addEventListener('input', e => { searchText = e.target.value; contacts(); });
    $('#category-filter').addEventListener('change', e => { categoryFilter = e.target.value; contacts(); });
    $('#add-contact').addEventListener('click', () => contactForm());
    document.querySelectorAll('[data-queue]').forEach(b =>
      b.addEventListener('click', e => {
        e.stopPropagation();
        Store.queueAdd(b.dataset.queue);
        b.textContent = '✓';
      }));
    bindOpenContact();
  }

  function contactDetail() {
    const c = Store.data.contacts.find(c => c.id === detailContactId);
    if (!c) { detailContactId = null; contacts(); return; }
    const reminders = Store.data.reminders
      .filter(r => r.contactId === c.id && !r.done)
      .sort((a, b) => a.due - b.due);

    main().innerHTML = `
      <button class="back-link" id="back">← Contacts</button>
      <div class="detail-header">
        ${avatarHTML(c, 64)}
        <div>
          <h2>${esc(fullName(c))}</h2>
          <div class="row-sub">${esc(c.title || '')}</div>
          <div style="margin-top:6px; display:flex; gap:6px; flex-wrap:wrap">
            <span class="chip">${esc(c.category)}</span>
            <span class="chip peach">${esc(c.stage)}</span>
          </div>
        </div>
      </div>
      <div class="toolbar">
        ${c.phone ? `<a class="btn-primary btn-small" href="${dialHref(c)}" style="text-decoration:none">📞 Call</a>` : ''}
        <button class="btn-ghost btn-small" id="queue-contact">＋ Queue</button>
        <button class="btn-ghost btn-small" id="edit-contact">Edit</button>
        <button class="btn-danger btn-small" id="delete-contact">Delete</button>
      </div>

      <div class="card">
        <h3>Contact info</h3>
        ${c.email ? `<div class="list-row">✉️ <a href="mailto:${esc(c.email)}">${esc(c.email)}</a></div>` : ''}
        ${c.phone ? `<div class="list-row">📞 <a href="tel:${esc(c.phone)}">${esc(c.phone)}</a></div>` : ''}
        ${!c.email && !c.phone ? '<p class="row-sub">No contact info.</p>' : ''}
      </div>

      <div class="card">
        <h3>Pipeline</h3>
        <div class="field"><label>Category</label>
          <select id="d-category">${Store.CATEGORIES.map(x => `<option ${c.category === x ? 'selected' : ''}>${x}</option>`).join('')}</select>
        </div>
        <div class="field"><label>Stage</label>
          <select id="d-stage">${Store.DEFAULT_STAGES.map(x => `<option ${c.stage === x ? 'selected' : ''}>${x}</option>`).join('')}</select>
        </div>
      </div>

      <div class="card">
        <h3>Notes <span class="chip">encrypted</span></h3>
        <textarea id="d-notes" rows="3" placeholder="Private notes…">${esc(c.notes)}</textarea>
      </div>
      <div class="card">
        <h3>Likes</h3>
        <textarea id="d-likes" rows="2">${esc(c.likes)}</textarea>
      </div>
      <div class="card">
        <h3>Dislikes</h3>
        <textarea id="d-dislikes" rows="2">${esc(c.dislikes)}</textarea>
      </div>

      <div class="card">
        <h3>Reminders</h3>
        ${reminders.map(r => `
          <div class="list-row">
            <div class="activity-icon">🔔</div>
            <div class="row-body">
              <div class="row-title">${esc(r.title)}</div>
              <div class="row-sub">${fmtDate(r.due)}</div>
            </div>
            <button class="btn-ghost btn-small" data-done-reminder="${r.id}">✓</button>
          </div>`).join('')}
        <div class="toolbar" style="margin-top:10px">
          <input id="rem-title" placeholder="Reminder…" style="flex:1">
          <input id="rem-due" type="datetime-local" style="width:auto">
          <button class="btn-ghost" id="add-reminder">Add</button>
        </div>
      </div>

      <div class="card">
        <h3>Log a point of contact</h3>
        <div class="toolbar">
          <select id="act-type" style="width:auto">
            ${Store.ACTIVITY_TYPES.map(t => `<option value="${t.id}">${t.icon} ${t.label}</option>`).join('')}
          </select>
          <input id="act-summary" placeholder="e.g. Emailed proposal v2" style="flex:1">
          <button class="btn-primary" id="add-activity">Log</button>
        </div>
      </div>

      <div class="card">
        <h3>Activity feed</h3>
        ${c.activities.length === 0 ? '<p class="row-sub">No activity yet.</p>' :
          c.activities.map(a => `
          <div class="activity-item">
            <div class="activity-icon">${activityIcon(a.type)}</div>
            <div class="row-body">
              <div>${esc(a.summary)}</div>
              <div class="activity-time">${fmtDate(a.ts)}</div>
            </div>
          </div>`).join('')}
      </div>
    `;

    $('#back').addEventListener('click', () => { detailContactId = null; contacts(); });
    $('#queue-contact').addEventListener('click', () => {
      Store.queueAdd(c.id);
      $('#queue-contact').textContent = '✓ Queued';
    });
    $('#edit-contact').addEventListener('click', () => contactForm(c));
    $('#delete-contact').addEventListener('click', () => {
      if (confirm(`Delete ${fullName(c)} and all CRM data for them?`)) {
        Store.deleteContact(c.id);
        detailContactId = null;
        contacts();
      }
    });
    $('#d-category').addEventListener('change', e => Store.updateContact(c.id, { category: e.target.value }));
    $('#d-stage').addEventListener('change', e => Store.updateContact(c.id, { stage: e.target.value }));
    let saveTimer;
    ['notes', 'likes', 'dislikes'].forEach(f => {
      $(`#d-${f}`).addEventListener('input', e => {
        clearTimeout(saveTimer);
        saveTimer = setTimeout(() => Store.updateContact(c.id, { [f]: e.target.value }), 400);
      });
    });
    $('#add-reminder').addEventListener('click', () => {
      const title = $('#rem-title').value.trim();
      const due = $('#rem-due').value;
      if (!title || !due) return;
      Store.addReminder(c.id, title, new Date(due).getTime());
      contactDetail();
    });
    document.querySelectorAll('[data-done-reminder]').forEach(b =>
      b.addEventListener('click', () => { Store.completeReminder(b.dataset.doneReminder); contactDetail(); }));
    $('#add-activity').addEventListener('click', () => {
      const summary = $('#act-summary').value.trim();
      if (!summary) return;
      Store.addActivity(c.id, $('#act-type').value, summary);
      contactDetail();
    });
  }

  function contactForm(existing) {
    const c = existing || {};
    showModal(`
      <h2>${existing ? 'Edit' : 'New'} Contact</h2>
      <div class="field"><label>First name</label><input id="f-first" value="${esc(c.firstName || '')}"></div>
      <div class="field"><label>Last name</label><input id="f-last" value="${esc(c.lastName || '')}"></div>
      <div class="field"><label>Title / role</label><input id="f-title" value="${esc(c.title || '')}"></div>
      <div class="field"><label>Email</label><input id="f-email" type="email" value="${esc(c.email || '')}"></div>
      <div class="field"><label>Phone</label><input id="f-phone" type="tel" value="${esc(c.phone || '')}"></div>
      <div class="field"><label>Category</label>
        <select id="f-category">${Store.CATEGORIES.map(x => `<option ${c.category === x ? 'selected' : ''}>${x}</option>`).join('')}</select>
      </div>
      <div class="field"><label>Photo</label><input id="f-photo" type="file" accept="image/*"></div>
      <div class="modal-actions">
        <button class="btn-ghost" data-close>Cancel</button>
        <button class="btn-primary" id="f-save">Save</button>
      </div>
    `);
    $('#f-save').addEventListener('click', async () => {
      const fields = {
        firstName: $('#f-first').value.trim(),
        lastName: $('#f-last').value.trim(),
        title: $('#f-title').value.trim(),
        email: $('#f-email').value.trim(),
        phone: $('#f-phone').value.trim(),
        category: $('#f-category').value,
      };
      if (!fields.firstName && !fields.lastName) return;
      const file = $('#f-photo').files[0];
      if (file) fields.photo = await fileToDataURL(file, 256);
      if (existing) Store.updateContact(existing.id, fields);
      else Store.addContact(fields);
      closeModal();
      render();
    });
  }

  /* ============ PIPELINES ============ */

  function pipelines() {
    const d = Store.data;
    const isDefault = !activePipelineId;
    const pipeline = d.pipelines.find(p => p.id === activePipelineId);
    const stages = isDefault
      ? Store.DEFAULT_STAGES.map(s => ({ id: s, name: s }))
      : (pipeline ? pipeline.stages : []);

    const contactsFor = stage => d.contacts.filter(c =>
      isDefault ? c.stage === stage.name : (c.pipelineId === activePipelineId && c.stageId === stage.id));

    main().innerHTML = `
      <h2 class="section-title">Pipelines</h2>
      <div class="pipeline-chips">
        <button class="pipeline-chip ${isDefault ? 'active' : ''}" data-pipeline="">Default</button>
        ${d.pipelines.map(p => `
          <button class="pipeline-chip ${p.id === activePipelineId ? 'active' : ''}" data-pipeline="${p.id}">${esc(p.name)}</button>`).join('')}
        <button class="pipeline-chip" id="new-pipeline">＋ New</button>
      </div>
      <div class="kanban">
        ${stages.map(stage => {
          const cs = contactsFor(stage);
          return `
          <div class="kanban-col" data-stage="${esc(stage.id)}">
            <h4>${esc(stage.name)} <span class="kanban-count">${cs.length}</span></h4>
            ${cs.map(c => `
              <div class="kanban-card" draggable="true" data-card="${c.id}" data-open-contact="${c.id}">
                <div class="row-title">${esc(fullName(c))}</div>
                <div class="row-sub">${esc(c.title || c.category)}</div>
              </div>`).join('')}
          </div>`;
        }).join('')}
      </div>
      ${!isDefault && pipeline ? `
        <div class="toolbar" style="margin-top:14px">
          <button class="btn-ghost btn-small" id="edit-pipeline">Edit stages</button>
          <button class="btn-danger btn-small" id="delete-pipeline">Delete pipeline</button>
        </div>` : ''}
    `;

    document.querySelectorAll('[data-pipeline]').forEach(b =>
      b.addEventListener('click', () => { activePipelineId = b.dataset.pipeline || null; pipelines(); }));
    $('#new-pipeline').addEventListener('click', () => {
      const name = prompt('Pipeline name');
      if (name?.trim()) { const p = Store.addPipeline(name.trim()); activePipelineId = p.id; pipelines(); }
    });
    if (!isDefault && pipeline) {
      $('#edit-pipeline').addEventListener('click', () => pipelineEditor(pipeline));
      $('#delete-pipeline').addEventListener('click', () => {
        if (confirm(`Delete pipeline "${pipeline.name}"?`)) {
          Store.deletePipeline(pipeline.id);
          activePipelineId = null;
          pipelines();
        }
      });
    }

    /* drag & drop */
    let draggedId = null;
    document.querySelectorAll('.kanban-card').forEach(card => {
      card.addEventListener('dragstart', () => { draggedId = card.dataset.card; });
    });
    document.querySelectorAll('.kanban-col').forEach(col => {
      col.addEventListener('dragover', e => { e.preventDefault(); col.classList.add('drag-over'); });
      col.addEventListener('dragleave', () => col.classList.remove('drag-over'));
      col.addEventListener('drop', e => {
        e.preventDefault();
        col.classList.remove('drag-over');
        if (!draggedId) return;
        const stageId = col.dataset.stage;
        if (isDefault) Store.updateContact(draggedId, { stage: stageId });
        else Store.updateContact(draggedId, { pipelineId: activePipelineId, stageId });
        draggedId = null;
        pipelines();
      });
    });
    bindOpenContact();
  }

  function pipelineEditor(pipeline) {
    showModal(`
      <h2>Edit "${esc(pipeline.name)}"</h2>
      <div id="stage-list">
        ${pipeline.stages.map(s => `
          <div class="field" style="display:flex; gap:8px">
            <input data-stage-name="${s.id}" value="${esc(s.name)}">
            <button class="btn-danger btn-small" data-del-stage="${s.id}">✕</button>
          </div>`).join('')}
      </div>
      <div class="field" style="display:flex; gap:8px">
        <input id="new-stage-name" placeholder="New stage…">
        <button class="btn-ghost" id="add-stage">Add</button>
      </div>
      <div class="modal-actions">
        <button class="btn-primary" data-close>Done</button>
      </div>
    `);
    document.querySelectorAll('[data-stage-name]').forEach(inp =>
      inp.addEventListener('change', () => Store.updatePipeline(pipeline.id, p => {
        const s = p.stages.find(s => s.id === inp.dataset.stageName);
        if (s) s.name = inp.value;
      })));
    document.querySelectorAll('[data-del-stage]').forEach(b =>
      b.addEventListener('click', () => {
        Store.updatePipeline(pipeline.id, p => {
          p.stages = p.stages.filter(s => s.id !== b.dataset.delStage);
        });
        closeModal(); pipelineEditor(pipeline);
      }));
    $('#add-stage').addEventListener('click', () => {
      const name = $('#new-stage-name').value.trim();
      if (!name) return;
      Store.updatePipeline(pipeline.id, p => p.stages.push({ id: crypto.randomUUID(), name }));
      closeModal(); pipelineEditor(pipeline);
    });
    document.querySelector('[data-close]').addEventListener('click', () => pipelines());
  }

  /* ============ CALL QUEUE (auto-advance dialer) ============ */

  function call() {
    const queued = Store.queueContacts();
    const dialApp = Store.data.dialApp || 'tel';

    main().innerHTML = `
      <h2 class="section-title">Call queue</h2>

      <div class="card">
        <h3>Dial with</h3>
        <div class="pipeline-chips" id="dial-apps">
          ${Store.DIAL_APPS.map(a => `
            <button class="pipeline-chip ${dialApp === a.id ? 'active' : ''}" data-app="${a.id}">${a.icon} ${a.label}</button>`).join('')}
        </div>
        <p class="row-sub" style="white-space:normal; line-height:1.5">
          Tapping “Call” opens the app with the number ready — iOS still needs one tap to connect,
          then it logs the call and advances to the next contact.
        </p>
      </div>

      ${queued.length === 0 ? `
        <div class="card"><div class="empty-state"><div class="big">📞</div>
        Queue is empty. Add contacts from the Contacts tab or from a contact's page.</div></div>` : `
        <div class="toolbar">
          <span class="chip">${queued.length} in queue</span>
          <button class="btn-ghost btn-small" id="clear-queue">Clear all</button>
        </div>
        ${queued.map((c, i) => `
          <div class="card" style="padding:14px">
            <div style="display:flex; align-items:center; gap:12px">
              ${avatarHTML(c)}
              <div class="row-body">
                <div class="row-title">${esc(fullName(c))} ${i === 0 ? '<span class="chip peach">next</span>' : ''}</div>
                <div class="row-sub">${esc(c.phone || 'no number')}</div>
              </div>
            </div>
            <div class="toolbar" style="margin-top:12px; margin-bottom:0">
              <button class="btn-primary" data-call="${c.id}" ${c.phone ? '' : 'disabled'}>📞 Call</button>
              <button class="btn-ghost btn-small" data-log="${c.id}">Log outcome</button>
              <button class="btn-danger btn-small" data-dequeue="${c.id}">Remove</button>
            </div>
          </div>`).join('')}
      `}
    `;

    document.querySelectorAll('[data-app]').forEach(b =>
      b.addEventListener('click', () => { Store.setDialApp(b.dataset.app); call(); }));
    const clr = $('#clear-queue');
    if (clr) clr.addEventListener('click', () => {
      if (confirm('Clear the whole call queue?')) { Store.queueClear(); call(); }
    });
    document.querySelectorAll('[data-call]').forEach(b =>
      b.addEventListener('click', () => placeCall(b.dataset.call)));
    document.querySelectorAll('[data-log]').forEach(b =>
      b.addEventListener('click', () => logCallOutcome(b.dataset.log)));
    document.querySelectorAll('[data-dequeue]').forEach(b =>
      b.addEventListener('click', () => { Store.queueRemove(b.dataset.dequeue); call(); }));
  }

  function placeCall(contactId) {
    const c = Store.data.contacts.find(c => c.id === contactId);
    if (!c || !c.phone) return;
    const app = Store.DIAL_APPS.find(a => a.id === (Store.data.dialApp || 'tel')) || Store.DIAL_APPS[0];
    const number = c.phone.replace(/[^\d+]/g, '');
    // Hand off to the phone/app. iOS presents its confirmation before connecting.
    window.location.href = app.scheme(number);
    // Offer to log + advance right after the hand-off.
    setTimeout(() => logCallOutcome(contactId, true), 800);
  }

  function logCallOutcome(contactId, advance) {
    const c = Store.data.contacts.find(c => c.id === contactId);
    if (!c) return;
    showModal(`
      <h2>Log call — ${esc(fullName(c))}</h2>
      <div class="field"><label>Outcome</label>
        <select id="call-outcome">
          <option>Connected</option>
          <option>Left voicemail</option>
          <option>No answer</option>
          <option>Wrong number</option>
          <option>Call back later</option>
        </select>
      </div>
      <div class="field"><label>Notes</label>
        <textarea id="call-notes" rows="3" placeholder="What happened…"></textarea>
      </div>
      <div class="field">
        <label><input type="checkbox" id="call-remove" checked style="width:auto; margin-right:6px">Remove from queue${advance ? ' and go to next' : ''}</label>
      </div>
      <div class="modal-actions">
        <button class="btn-ghost" data-close>Skip</button>
        <button class="btn-primary" id="call-save">Save</button>
      </div>
    `);
    $('#call-save').addEventListener('click', () => {
      const outcome = $('#call-outcome').value;
      const notes = $('#call-notes').value.trim();
      Store.addActivity(contactId, 'call', notes ? `${outcome} — ${notes}` : outcome);
      if ($('#call-remove').checked) Store.queueRemove(contactId);
      closeModal();
      call();
    });
  }

  /* ============ REMINDERS ============ */

  function reminders() {
    const d = Store.data;
    const upcoming = Store.upcomingReminders();
    const groups = {};
    upcoming.forEach(r => {
      const key = new Date(r.due).toLocaleDateString(undefined, { weekday: 'short', month: 'short', day: 'numeric' });
      (groups[key] = groups[key] || []).push(r);
    });

    main().innerHTML = `
      <h2 class="section-title">Reminders</h2>
      ${upcoming.length === 0 ? `
        <div class="card"><div class="empty-state"><div class="big">🔔</div>
        No reminders. Add one from any contact.</div></div>` :
        Object.entries(groups).map(([label, rs]) => `
        <div class="card">
          <h3>${esc(label)}</h3>
          ${rs.map(r => {
            const c = d.contacts.find(c => c.id === r.contactId);
            return `
            <div class="list-row">
              <div class="activity-icon">🔔</div>
              <div class="row-body" data-open-contact="${r.contactId}">
                <div class="row-title">${esc(r.title)}</div>
                <div class="row-sub">${c ? esc(fullName(c)) + ' · ' : ''}${new Date(r.due).toLocaleTimeString([], { hour: 'numeric', minute: '2-digit' })}</div>
              </div>
              <button class="btn-ghost btn-small" data-done-reminder="${r.id}">✓</button>
              <button class="btn-danger btn-small" data-del-reminder="${r.id}">✕</button>
            </div>`;
          }).join('')}
        </div>`).join('')}
    `;
    document.querySelectorAll('[data-done-reminder]').forEach(b =>
      b.addEventListener('click', () => { Store.completeReminder(b.dataset.doneReminder); reminders(); }));
    document.querySelectorAll('[data-del-reminder]').forEach(b =>
      b.addEventListener('click', () => { Store.deleteReminder(b.dataset.delReminder); reminders(); }));
    bindOpenContact();
  }

  /* ============ SETTINGS ============ */

  function settings() {
    const d = Store.data;
    main().innerHTML = `
      <h2 class="section-title">Settings</h2>

      <div class="card">
        <h3>Security</h3>
        <p class="row-sub" style="white-space:normal; line-height:1.5">
          🔒 All CRM data is AES-GCM encrypted with a non-extractable WebCrypto key held in
          this browser's IndexedDB. Nothing is uploaded — Google sign-in is used for identity only.
        </p>
      </div>

      <div class="card">
        <h3>Pipelines</h3>
        ${d.pipelines.length === 0 ? '<p class="row-sub">No custom pipelines.</p>' :
          d.pipelines.map(p => `
          <div class="list-row">
            <div class="row-body"><div class="row-title">${esc(p.name)}</div>
            <div class="row-sub">${p.stages.length} stages</div></div>
            <button class="btn-danger btn-small" data-del-pipeline="${p.id}">Delete</button>
          </div>`).join('')}
        <button class="btn-ghost btn-small" id="s-new-pipeline" style="margin-top:8px">+ New pipeline</button>
      </div>

      <div class="card">
        <h3>Data</h3>
        <p class="row-sub" style="margin-bottom:10px">${d.contacts.length} contacts · ${d.reminders.length} reminders</p>
        <button class="btn-danger" id="wipe-data">Delete all CRM data</button>
      </div>

      <div class="card">
        <h3>About</h3>
        <p class="row-sub">ContactCRM web · local-only, encrypted at rest</p>
      </div>
    `;
    $('#s-new-pipeline').addEventListener('click', () => {
      const name = prompt('Pipeline name');
      if (name?.trim()) { Store.addPipeline(name.trim()); settings(); }
    });
    document.querySelectorAll('[data-del-pipeline]').forEach(b =>
      b.addEventListener('click', () => {
        if (confirm('Delete this pipeline?')) { Store.deletePipeline(b.dataset.delPipeline); settings(); }
      }));
    $('#wipe-data').addEventListener('click', () => {
      if (confirm('Delete ALL contacts, reminders, and pipelines stored in this browser? This cannot be undone.')) {
        Store.wipe();
        settings();
      }
    });
  }

  /* ============ HELPERS ============ */

  const fullName = c => [c.firstName, c.lastName].filter(Boolean).join(' ') || '(no name)';

  function dialHref(c) {
    const app = Store.DIAL_APPS.find(a => a.id === (Store.data.dialApp || 'tel')) || Store.DIAL_APPS[0];
    return app.scheme((c.phone || '').replace(/[^\d+]/g, ''));
  }

  function avatarHTML(c, size) {
    const style = size ? `style="width:${size}px;height:${size}px"` : '';
    if (c.photo) return `<div class="avatar" ${style}><img src="${c.photo}" alt=""></div>`;
    const initials = (c.firstName?.[0] || '') + (c.lastName?.[0] || '');
    return `<div class="avatar" ${style}>${esc(initials.toUpperCase() || '?')}</div>`;
  }

  const activityIcon = type =>
    (Store.ACTIVITY_TYPES.find(t => t.id === type) || {}).icon || '•';

  const fmtDate = ts => new Date(ts).toLocaleString(undefined,
    { month: 'short', day: 'numeric', hour: 'numeric', minute: '2-digit' });

  function fileToDataURL(file, maxDim) {
    return new Promise(resolve => {
      const img = new Image();
      img.onload = () => {
        const scale = Math.min(1, maxDim / Math.max(img.width, img.height));
        const canvas = document.createElement('canvas');
        canvas.width = img.width * scale;
        canvas.height = img.height * scale;
        canvas.getContext('2d').drawImage(img, 0, 0, canvas.width, canvas.height);
        resolve(canvas.toDataURL('image/jpeg', 0.82));
      };
      img.src = URL.createObjectURL(file);
    });
  }

  function bindOpenContact() {
    document.querySelectorAll('[data-open-contact]').forEach(el =>
      el.addEventListener('click', e => {
        if (e.target.closest('button')) return;
        detailContactId = el.dataset.openContact;
        view = 'contacts';
        render();
      }));
  }

  function showModal(html) {
    $('#modal-root').innerHTML = `
      <div class="modal-backdrop">
        <div class="modal">${html}</div>
      </div>`;
    $('.modal-backdrop').addEventListener('click', e => {
      if (e.target.classList.contains('modal-backdrop')) closeModal();
    });
    document.querySelectorAll('[data-close]').forEach(b =>
      b.addEventListener('click', closeModal));
  }

  function closeModal() { $('#modal-root').innerHTML = ''; }

  /* ============ INIT ============ */

  function init() {
    document.querySelectorAll('.tab').forEach(t =>
      t.addEventListener('click', () => go(t.dataset.view)));
    $('#signout').addEventListener('click', signOut);
    $('#demo-login').addEventListener('click', demoLogin);

    const saved = sessionStorage.getItem('contactcrm-user');
    if (saved) {
      user = JSON.parse(saved);
      enterApp();
    } else {
      initGoogleSignIn();
    }
  }

  document.addEventListener('DOMContentLoaded', init);
  return { render };
})();
