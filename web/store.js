/* Encrypted local store. The whole CRM document is AES-GCM encrypted as one
   blob in localStorage; nothing readable at rest, nothing leaves the browser. */

const Store = (() => {
  const LS_KEY = 'contactcrm-data';

  const DEFAULT_STAGES = ['New Lead', 'Contacted', 'Appointment Set', 'Negotiation', 'Won', 'Lost'];
  const CATEGORIES = ['New Lead', 'Warm Lead', 'Client', 'Previous Client', 'Vendor', 'Other'];
  const ACTIVITY_TYPES = [
    { id: 'note', label: 'Note', icon: '📝' },
    { id: 'call', label: 'Call', icon: '📞' },
    { id: 'email', label: 'Email', icon: '✉️' },
    { id: 'meeting', label: 'Meeting', icon: '📅' },
    { id: 'message', label: 'Message', icon: '💬' },
  ];

  let data = null;

  function blank() {
    return {
      contacts: [],   // {id, firstName, lastName, title, email, phone, photo, category, stage, pipelineId, stageId, notes, likes, dislikes, activities:[], createdAt, updatedAt}
      pipelines: [],  // {id, name, stages:[{id, name}]}
      reminders: [],  // {id, contactId, title, due, done}
    };
  }

  async function load() {
    const raw = localStorage.getItem(LS_KEY);
    if (!raw) { data = blank(); return data; }
    try {
      data = JSON.parse(await CryptoLayer.decrypt(raw));
    } catch (e) {
      console.error('Could not decrypt store', e);
      data = blank();
    }
    return data;
  }

  async function save() {
    localStorage.setItem(LS_KEY, await CryptoLayer.encrypt(JSON.stringify(data)));
  }

  const uid = () => crypto.randomUUID();

  /* Contacts */
  function addContact(fields) {
    const c = {
      id: uid(),
      firstName: '', lastName: '', title: '', email: '', phone: '', photo: null,
      category: 'New Lead', stage: DEFAULT_STAGES[0], pipelineId: null, stageId: null,
      notes: '', likes: '', dislikes: '',
      activities: [],
      createdAt: Date.now(), updatedAt: Date.now(),
      ...fields,
    };
    data.contacts.push(c);
    save();
    return c;
  }

  function updateContact(id, fields) {
    const c = data.contacts.find(c => c.id === id);
    if (!c) return null;
    Object.assign(c, fields, { updatedAt: Date.now() });
    save();
    return c;
  }

  function deleteContact(id) {
    data.contacts = data.contacts.filter(c => c.id !== id);
    data.reminders = data.reminders.filter(r => r.contactId !== id);
    save();
  }

  function addActivity(contactId, type, summary) {
    const c = data.contacts.find(c => c.id === contactId);
    if (!c) return;
    c.activities.unshift({ id: uid(), type, summary, ts: Date.now() });
    c.updatedAt = Date.now();
    save();
  }

  /* Pipelines */
  function addPipeline(name) {
    const p = {
      id: uid(), name,
      stages: DEFAULT_STAGES.map(s => ({ id: uid(), name: s })),
    };
    data.pipelines.push(p);
    save();
    return p;
  }

  function updatePipeline(id, fn) {
    const p = data.pipelines.find(p => p.id === id);
    if (!p) return;
    fn(p);
    save();
  }

  function deletePipeline(id) {
    data.pipelines = data.pipelines.filter(p => p.id !== id);
    data.contacts.forEach(c => {
      if (c.pipelineId === id) { c.pipelineId = null; c.stageId = null; }
    });
    save();
  }

  /* Reminders */
  function addReminder(contactId, title, due) {
    const r = { id: uid(), contactId, title, due, done: false };
    data.reminders.push(r);
    save();
    return r;
  }

  function completeReminder(id) {
    const r = data.reminders.find(r => r.id === id);
    if (r) { r.done = true; save(); }
  }

  function deleteReminder(id) {
    data.reminders = data.reminders.filter(r => r.id !== id);
    save();
  }

  function upcomingReminders() {
    return data.reminders
      .filter(r => !r.done)
      .sort((a, b) => a.due - b.due);
  }

  function wipe() {
    data = blank();
    save();
  }

  return {
    load, save, wipe,
    get data() { return data; },
    DEFAULT_STAGES, CATEGORIES, ACTIVITY_TYPES,
    addContact, updateContact, deleteContact, addActivity,
    addPipeline, updatePipeline, deletePipeline,
    addReminder, completeReminder, deleteReminder, upcomingReminders,
  };
})();
