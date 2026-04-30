const vm = require('vm');

const APPOINTMENT_URL = 'http://localhost:3000/a/b2';

function makeElement(id, className) {
  return {
    id,
    className: className || '',
    innerHTML: '',
    textContent: '',
    style: { display: '' },
    disabled: false,
    value: '',
    focused: false,
    listeners: {},
    attributes: {},
    addEventListener(type, handler) {
      this.listeners[type] = handler;
    },
    getAttribute(name) {
      return Object.prototype.hasOwnProperty.call(this.attributes, name) ? this.attributes[name] : null;
    },
    setAttribute(name, value) {
      this.attributes[name] = String(value);
    },
    focus() {
      this.focused = true;
    },
  };
}

async function main() {
  const response = await fetch(APPOINTMENT_URL);
  const html = await response.text();
  const match = html.match(/<script>([\s\S]*?)<\/script>/i);
  if (!match) {
    throw new Error('Appointment page script block not found');
  }

  const elements = {
    svcList: makeElement('svcList'),
    dateRow: makeElement('dateRow'),
    slotsContainer: makeElement('slotsContainer'),
    summaryBox: makeElement('summaryBox'),
    guestName: makeElement('guestName'),
    confirmBtn: makeElement('confirmBtn', 'btn'),
    globalErr: makeElement('globalErr'),
    successBox: makeElement('successBox'),
    successDetail: makeElement('successDetail'),
    dots: makeElement('dots'),
    step0: makeElement('step0', 'step active'),
    step1: makeElement('step1', 'step'),
    step2: makeElement('step2', 'step'),
    d0: makeElement('d0', 'dot active'),
    d1: makeElement('d1', 'dot'),
    d2: makeElement('d2', 'dot'),
    backToServicesBtn: makeElement('backToServicesBtn', 'btn btn-back'),
    backToSlotsBtn: makeElement('backToSlotsBtn', 'btn btn-back'),
  };

  elements.successBox.style.display = 'none';

  const stubSlots = [
    {
      id: 'slot-1',
      business_id: 'b2',
      start_time: '2026-04-18T09:00:00.000Z',
      end_time: '2026-04-18T10:00:00.000Z',
      is_booked: 0,
    },
    {
      id: 'slot-2',
      business_id: 'b2',
      start_time: '2026-04-18T10:00:00.000Z',
      end_time: '2026-04-18T11:00:00.000Z',
      is_booked: 1,
    },
  ];

  let lastRequest = null;

  function FakeXMLHttpRequest() {
    this.readyState = 0;
    this.status = 0;
    this.responseText = '';
    this.headers = {};
  }

  FakeXMLHttpRequest.prototype.open = function open(method, url) {
    this.method = method;
    this.url = url;
  };

  FakeXMLHttpRequest.prototype.setRequestHeader = function setRequestHeader(name, value) {
    this.headers[name] = value;
  };

  FakeXMLHttpRequest.prototype.send = function send(body) {
    lastRequest = {
      method: this.method,
      url: this.url,
      headers: this.headers,
      body: body ? JSON.parse(body) : null,
    };

    this.readyState = 4;
    if (this.method === 'GET') {
      this.status = 200;
      this.responseText = JSON.stringify(stubSlots);
    } else if (this.method === 'POST') {
      this.status = 201;
      this.responseText = JSON.stringify({
        id: 'appt-1',
        service_name: lastRequest.body.service_name,
        date_time: lastRequest.body.date_time,
        final_price: 150,
      });
    } else {
      this.status = 400;
      this.responseText = JSON.stringify({ error: 'Unsupported method' });
    }

    if (typeof this.onreadystatechange === 'function') {
      this.onreadystatechange();
    }
  };

  const sandbox = {
    document: {
      getElementById(id) {
        return elements[id] || null;
      },
    },
    XMLHttpRequest: FakeXMLHttpRequest,
    setTimeout(fn) {
      if (typeof fn === 'function') {
        fn();
      }
      return 1;
    },
    clearTimeout() {},
    console,
  };
  sandbox.window = sandbox;

  vm.createContext(sandbox);
  vm.runInContext(match[1], sandbox, { timeout: 2000 });

  if (typeof elements.svcList.listeners.click !== 'function') {
    throw new Error('Service list click handler was not registered');
  }

  const firstService = sandbox.SVCS && sandbox.SVCS[0];
  if (!firstService) {
    throw new Error('No services exposed by appointment page script');
  }

  const serviceTarget = makeElement('serviceTarget', 'svc');
  serviceTarget.setAttribute('data-service-id', firstService.id);
  serviceTarget.parentNode = elements.svcList;
  elements.svcList.listeners.click({ target: serviceTarget });

  const dateTarget = makeElement('dateTarget', 'date-pill');
  dateTarget.setAttribute('data-date', '2026-04-18');
  dateTarget.parentNode = elements.dateRow;
  if (typeof elements.dateRow.listeners.click !== 'function') {
    throw new Error('Date row click handler was not registered');
  }
  elements.dateRow.listeners.click({ target: dateTarget });

  if (typeof elements.slotsContainer.listeners.click !== 'function') {
    throw new Error('Slots container click handler was not registered');
  }
  const slotTarget = makeElement('slotTarget', 'slot');
  slotTarget.setAttribute('data-slot-id', 'slot-1');
  slotTarget.parentNode = elements.slotsContainer;
  elements.slotsContainer.listeners.click({ target: slotTarget });

  elements.guestName.value = 'Test Appointment Guest';
  if (typeof sandbox.confirmBooking !== 'function') {
    throw new Error('confirmBooking function is not available');
  }
  sandbox.confirmBooking();

  const results = {
    movedToStep1: elements.step1.className.indexOf('active') !== -1 || sandbox.selDate !== null,
    slotsLoaded: elements.slotsContainer.innerHTML.indexOf('slot-1') !== -1,
    summaryIncludesService: elements.summaryBox.innerHTML.indexOf(firstService.name) !== -1,
    successVisible: elements.successBox.style.display === 'block',
    successIncludesService: elements.successDetail.innerHTML.indexOf(firstService.name) !== -1,
    postedPayload: lastRequest,
  };

  console.log(JSON.stringify(results, null, 2));
}

main().catch((error) => {
  console.error(error && error.stack ? error.stack : String(error));
  process.exit(1);
});