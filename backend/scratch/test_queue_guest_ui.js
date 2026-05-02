const vm = require('vm');

const QUEUE_URL = 'http://localhost:3000/q/0c1a762f-73e3-4565-9da0-39920ede2fd4';

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
  const response = await fetch(QUEUE_URL);
  const html = await response.text();
  const match = html.match(/<script>([\s\S]*?)<\/script>/i);
  if (!match) {
    throw new Error('Queue page script block not found');
  }

  const elements = {
    prodList: makeElement('prodList'),
    serviceNote: makeElement('serviceNote'),
    cartTotal: makeElement('cartTotal'),
    cartCount: makeElement('cartCount'),
    orderBtn: makeElement('orderBtn', 'btn'),
    orderBox: makeElement('orderBox'),
    drawerOverlay: makeElement('drawerOverlay', 'drawer-overlay'),
    nameInput: makeElement('nameInput'),
    joinBtn: makeElement('joinBtn', 'btn btn-full'),
    drawerErr: makeElement('drawerErr'),
    mainPage: makeElement('mainPage'),
    cartBar: makeElement('cartBar'),
    successPage: makeElement('successPage'),
    posNum: makeElement('posNum'),
    successSub: makeElement('successSub'),
    pageErr: makeElement('pageErr'),
  };

  elements.successPage.style.display = 'none';
  elements.orderBtn.disabled = true;
  elements.cartCount.textContent = 'Select items to order';

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
    this.status = 201;
    this.responseText = JSON.stringify({
      position: 3,
      pricing: { total: 64868 },
    });
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

  const firstProduct = sandbox.PRODS && sandbox.PRODS[0];
  if (!firstProduct) {
    throw new Error('No products exposed by queue page script');
  }

  const plusButton = makeElement('plusButton', 'qb');
  plusButton.setAttribute('data-id', firstProduct.id);
  plusButton.setAttribute('data-delta', '1');
  plusButton.parentNode = elements.prodList;

  if (typeof elements.prodList.listeners.click !== 'function') {
    throw new Error('Product list click handler was not registered');
  }

  elements.prodList.listeners.click({ target: plusButton });
  const orderBtnEnabled = elements.orderBtn.disabled === false;
  const cartCountUpdated = elements.cartCount.textContent !== 'Select items to order';
  const orderBoxIncludesProduct = elements.orderBox.innerHTML.indexOf(firstProduct.name) !== -1;

  if (typeof elements.orderBtn.listeners.click !== 'function') {
    throw new Error('Order button click handler was not registered');
  }
  elements.orderBtn.listeners.click({ target: elements.orderBtn });
  const drawerOpened = elements.drawerOverlay.className.indexOf('open') !== -1;

  elements.nameInput.value = 'Test Guest';
  if (typeof sandbox.joinQueue !== 'function') {
    throw new Error('joinQueue function is not available');
  }
  sandbox.joinQueue();

  const results = {
    orderBtnEnabled,
    cartCountText: elements.cartCount.textContent,
    orderBoxIncludesProduct,
    drawerOpened,
    successPageDisplay: elements.successPage.style.display,
    posNumText: elements.posNum.textContent,
    successContainsPrice: elements.successSub.innerHTML.indexOf('$64868.00') !== -1,
    postedPayload: lastRequest,
  };

  console.log(JSON.stringify(results, null, 2));
}

main().catch((error) => {
  console.error(error && error.stack ? error.stack : String(error));
  process.exit(1);
});