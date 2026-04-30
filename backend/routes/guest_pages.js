/**
 * Guest QR Web Pages
 *
 * /q/:businessId  → Queue ordering page   (browse menu → cart → name → join queue)
 * /a/:businessId  → Appointment booking   (service → date + slot → name → confirm)
 * /join/:bid      → Legacy redirect       (backwards compatible with old QR codes)
 */

const express = require('express');
const { pool } = require('../db');
const router = express.Router();

function escapeHtml(value) {
  return String(value || '')
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#39;');
}

function formatMoney(value) {
  return `$${Number(value || 0).toFixed(2)}`;
}

function setGuestPageHeaders(res) {
  res.set({
    'Cache-Control': 'no-store, no-cache, must-revalidate, proxy-revalidate',
    'Pragma': 'no-cache',
    'Expires': '0',
    'Surrogate-Control': 'no-store',
  });
}

// ──────────────────────────────────────────────────────────────────────────────
// Legacy redirect — keep old QR codes working
// ──────────────────────────────────────────────────────────────────────────────
router.get('/join/:businessId', async (req, res) => {
  try {
    const [biz] = await pool.query('SELECT service_type FROM businesses WHERE id = ?', [req.params.businessId]);
    if (biz.length === 0) return res.status(404).send('<h2>Business not found</h2>');
    const t = biz[0].service_type || 'queue';
    return t === 'appointment'
      ? res.redirect(`/a/${req.params.businessId}`)
      : res.redirect(`/q/${req.params.businessId}`);
  } catch (e) { res.status(500).send('<h2>Server error</h2>'); }
});

// ──────────────────────────────────────────────────────────────────────────────
// Queue page — /q/:businessId
// ──────────────────────────────────────────────────────────────────────────────
router.get('/q/:businessId', async (req, res) => {
  try {
    const bId = req.params.businessId;
    const [biz] = await pool.query('SELECT name, address FROM businesses WHERE id = ?', [bId]);
    if (biz.length === 0) return res.status(404).send('<h2>Business not found</h2>');

    const [wRow] = await pool.query("SELECT COUNT(*) as cnt FROM queue_entries WHERE business_id = ? AND status = 'waiting'", [bId]);
    const [qRow] = await pool.query('SELECT is_paused FROM queues WHERE business_id = ?', [bId]);
    const [products] = await pool.query(
      `SELECT id, name, description, price, stock, is_off_sale FROM products WHERE business_id = ? AND is_available = 1 ORDER BY name ASC`,
      [bId]
    );

    const prods = products.map(p => ({
      id: p.id,
      name: p.name,
      description: p.description || '',
      price: parseFloat(p.price || 0) || 0,
      stock: parseInt(p.stock?.toString() || '0', 10) || 0,
    }));
    const initialProductsHtml = prods.length === 0
      ? '<div class="no-prods">No items available yet.</div>'
      : prods.map((product) => {
          const desc = product.description ? `<div class="prod-desc">${escapeHtml(product.description)}</div>` : '';
          return `<div class="prod">
      <div class="prod-info"><div class="prod-name">${escapeHtml(product.name)}</div>${desc}<div class="prod-price">${formatMoney(product.price)}</div></div>
      <div class="qty-wrap"><button type="button" class="qb" data-id="${product.id}" data-delta="-1">&#8722;</button><span class="qv">0</span><button type="button" class="qb" data-id="${product.id}" data-delta="1">+</button></div>
    </div>`;
        }).join('');

    const isPaused = qRow[0]?.is_paused;
    const waitCount = wRow[0].cnt;

    setGuestPageHeaders(res);
    res.send(`<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width,initial-scale=1">
  <meta http-equiv="Cache-Control" content="no-store, no-cache, must-revalidate, max-age=0">
  <meta http-equiv="Pragma" content="no-cache">
  <meta http-equiv="Expires" content="0">
  <title>${biz[0].name} – Order &amp; Join Queue</title>
  <style>
    *{box-sizing:border-box;margin:0;padding:0}
    body{font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',sans-serif;background:linear-gradient(160deg,#0f172a 0%,#131c2e 100%);color:#f1f5f9;min-height:100vh}
    .page{max-width:580px;margin:0 auto;padding:24px 16px 130px}
    .biz-name{font-size:24px;font-weight:800;letter-spacing:-0.5px}
    .biz-addr{color:#64748b;font-size:13px;margin-top:2px}
    .badge{display:inline-flex;align-items:center;gap:6px;background:rgba(56,189,248,.13);color:#7dd3fc;padding:7px 14px;border-radius:20px;font-size:12px;font-weight:700;margin:14px 0 0}
    .paused-bar{background:rgba(245,158,11,.1);border:1px solid rgba(245,158,11,.28);color:#fbbf24;padding:12px 16px;border-radius:14px;font-size:13px;margin-top:14px;text-align:center}
    .sect{font-size:11px;font-weight:800;color:#475569;text-transform:uppercase;letter-spacing:1.2px;margin:24px 0 12px}
    .prod{display:flex;align-items:center;gap:14px;padding:16px;border-radius:18px;border:1px solid rgba(148,163,184,.12);background:rgba(30,41,59,.7);margin-bottom:10px;transition:border-color .15s}
    .prod.in-cart{border-color:rgba(56,189,248,.35)}
    .prod-info{flex:1;min-width:0}
    .prod-name{font-size:15px;font-weight:700}
    .prod-desc{color:#94a3b8;font-size:12px;margin-top:3px;overflow:hidden;display:-webkit-box;-webkit-line-clamp:2;-webkit-box-orient:vertical}
    .prod-price{color:#38bdf8;font-size:14px;font-weight:800;margin-top:6px}
    .qty-wrap{display:flex;align-items:center;gap:8px;flex-shrink:0}
    .qb{width:36px;height:36px;border-radius:10px;background:rgba(51,65,85,.9);border:none;color:#e2e8f0;font-size:20px;cursor:pointer;display:flex;align-items:center;justify-content:center;transition:background .1s;touch-action:manipulation}
    .qb:active{background:rgba(56,189,248,.25)}
    .qv{min-width:22px;text-align:center;font-size:16px;font-weight:800;color:#f1f5f9}
    .oos-label{font-size:11px;color:#f87171;padding:4px 8px;background:rgba(239,68,68,.1);border-radius:8px;white-space:nowrap}
    .hidden{display:none !important}
    /* Cart bar */
    .cart-bar{position:fixed;bottom:0;left:0;right:0;background:rgba(10,15,28,.97);border-top:1px solid rgba(148,163,184,.15);padding:14px 16px;z-index:50}
    .cart-bar-inner{max-width:580px;margin:0 auto;display:flex;align-items:center;justify-content:space-between;gap:12px}
    .cart-total-label{font-size:12px;color:#64748b}
    .cart-total-val{font-size:22px;font-weight:800;color:#f1f5f9;line-height:1}
    .cart-items-count{font-size:11px;color:#7dd3fc;margin-top:1px}
    .btn{padding:14px 24px;background:linear-gradient(135deg,#0ea5e9,#2563eb);border:none;border-radius:14px;color:#fff;font-size:15px;font-weight:700;cursor:pointer;transition:opacity .15s;white-space:nowrap;touch-action:manipulation}
    .btn:disabled{opacity:.4;cursor:not-allowed}
    .note-block{margin-top:22px}
    .note-head{font-size:11px;font-weight:800;color:#475569;text-transform:uppercase;letter-spacing:1.2px;margin-bottom:10px}
    .helper{color:#94a3b8;font-size:12px;margin-top:8px;line-height:1.4}
    /* Drawer */
    .drawer-overlay{position:fixed;inset:0;background:rgba(0,0,0,.65);z-index:100;display:none;align-items:flex-end;justify-content:center}
    .drawer-overlay.open{display:flex}
    .drawer{background:#1a2332;border-radius:26px 26px 0 0;padding:24px 20px 36px;width:100%;max-width:580px}
    .handle{width:38px;height:4px;background:rgba(148,163,184,.25);border-radius:2px;margin:0 auto 22px}
    .drawer-title{font-size:20px;font-weight:800;margin-bottom:4px}
    .drawer-sub{color:#64748b;font-size:13px;margin-bottom:18px}
    .order-box{background:rgba(15,23,42,.7);border:1px solid rgba(148,163,184,.12);border-radius:14px;padding:14px;margin-bottom:18px}
    .oi{display:flex;justify-content:space-between;font-size:13px;color:#94a3b8;padding:3px 0}
    .ototal{display:flex;justify-content:space-between;font-size:17px;font-weight:800;color:#f1f5f9;padding-top:10px;margin-top:8px;border-top:1px solid rgba(148,163,184,.12)}
    label{font-size:13px;color:#cbd5e1;font-weight:600;display:block;margin-bottom:8px}
    input{width:100%;padding:14px 16px;background:rgba(15,23,42,.85);border:1.5px solid rgba(100,116,139,.25);border-radius:14px;color:#f1f5f9;font-size:16px;outline:none;margin-bottom:14px;transition:border-color .15s}
    input:focus{border-color:#38bdf8}
    .err{background:rgba(239,68,68,.1);color:#f87171;padding:12px;border-radius:10px;font-size:13px;margin-bottom:12px;display:none}
    .btn-full{width:100%;padding:16px}
    /* Success */
    .success-page{display:none;padding:48px 20px;text-align:center}
    .success-icon{font-size:64px;margin-bottom:16px}
    .success-title{font-size:26px;font-weight:800;margin-bottom:8px;color:#10b981}
    .success-sub{color:#64748b;font-size:14px;line-height:1.6}
    .pos-num{font-size:72px;font-weight:900;color:#38bdf8;line-height:1;margin:12px 0}
    .no-prods{text-align:center;color:#475569;padding:60px 20px;font-size:14px}
  </style>
</head>
<body>
<div class="page" id="mainPage">
  <p class="biz-name">${biz[0].name}</p>
  <p class="biz-addr">${biz[0].address || ''}</p>
  <div class="badge">&#128101; ${waitCount} ${waitCount === 1 ? 'person' : 'people'} waiting</div>
  ${isPaused ? '<div class="paused-bar">&#9208; Queue is currently paused &mdash; you can still join.</div>' : ''}
  <div class="err" id="pageErr"></div>
  <div class="sect">Menu</div>
  <div id="prodList">${initialProductsHtml}</div>

  <div class="note-block ${prods.length > 0 ? 'hidden' : ''}" id="noteBlock">
    <div class="note-head">Order Note</div>
    <label for="serviceNote">What would you like?</label>
    <input id="serviceNote" type="text" placeholder="Optional note for the business">
    <div class="helper">Use this if the business works without a visible product list.</div>
  </div>
</div>

<div class="success-page" id="successPage">
  <div class="success-icon">&#127881;</div>
  <div class="success-title">You&apos;re in the Queue!</div>
  <div class="pos-num" id="posNum">#1</div>
  <div class="success-sub" id="successSub"></div>
</div>

<div class="cart-bar" id="cartBar">
  <div class="cart-bar-inner">
    <div>
      <div class="cart-total-label">Cart Total</div>
      <div class="cart-total-val" id="cartTotal">$0.00</div>
      <div class="cart-items-count" id="cartCount">Select items to order</div>
    </div>
    <button type="button" class="btn" id="orderBtn" disabled>Place Order &rarr;</button>
  </div>
</div>

<!-- Name drawer -->
<div class="drawer-overlay" id="drawerOverlay">
  <div class="drawer">
    <div class="handle"></div>
    <div class="drawer-title">Almost Done!</div>
    <div class="drawer-sub">Review your order and enter your name to join the queue.</div>
    <div class="order-box" id="orderBox"></div>
    <div class="err" id="drawerErr"></div>
    <label for="nameInput">Your Name</label>
    <input id="nameInput" type="text" placeholder="Enter your name" autocomplete="name">
    <button type="button" class="btn btn-full" id="joinBtn">Join Queue &rarr;</button>
  </div>
</div>

<script>
var BID = ${JSON.stringify(bId)};
var PRODS = ${JSON.stringify(prods)};
var cart = {};

function getEl(id){return document.getElementById(id);}
function esc(v){return String(v == null ? '' : v).replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;');}
function fmt(v){return '$'+Number(v||0).toFixed(2);}
function hasClass(el,className){return !!el&&(' '+(el.className||'')+' ').indexOf(' '+className+' ')!==-1;}
function addClass(el,className){if(!el)return;if(!hasClass(el,className)){el.className=((el.className||'')+' '+className).replace(/^\s+|\s+$/g,'');}}
function removeClass(el,className){if(!el)return;el.className=(' '+(el.className||' ')+' ').replace(' '+className+' ',' ').replace(/^\s+|\s+$/g,'');}
function getServiceNote(){var noteEl=getEl('serviceNote');return noteEl?String(noteEl.value||'').trim():'';}

function findProduct(productId){
  for(var i=0;i<PRODS.length;i+=1){
    if(PRODS[i].id===productId)return PRODS[i];
  }
  return null;
}

function cartItems(){
  var items=[];
  for(var i=0;i<PRODS.length;i+=1){
    var product=PRODS[i];
    var qty=cart[product.id]||0;
    if(qty>0){
      items.push({
        id:product.id,
        name:product.name,
        description:product.description,
        price:product.price,
        stock:product.stock,
        qty:qty
      });
    }
  }
  return items;
}

function cartSubtotal(){
  var items=cartItems();
  var total=0;
  for(var i=0;i<items.length;i+=1){
    total+=Number(items[i].price||0)*items[i].qty;
  }
  return total;
}

function cartTotal(){return cartSubtotal();}

function showError(targetId,message){
  var el=getEl(targetId);
  if(!el)return;
  el.textContent=message;
  el.style.display='block';
}

function hideError(targetId){
  var el=getEl(targetId);
  if(!el)return;
  el.textContent='';
  el.style.display='none';
}

function changeQty(productId,delta){
  var product=findProduct(productId);
  var stock,maxQty,currentQty,nextQty;
  if(!product)return;
  stock=parseInt(product.stock,10);
  maxQty=stock>0?stock:99;
  currentQty=cart[productId]||0;
  nextQty=currentQty+delta;
  if(nextQty<0)nextQty=0;
  if(nextQty>maxQty)nextQty=maxQty;
  if(nextQty===0)delete cart[productId];else cart[productId]=nextQty;
  renderProds();
  updateBar();
}

function renderQtyControls(productId,qty){
  return '<div class="qty-wrap"><button type="button" class="qb" data-id="'+productId+'" data-delta="-1">&#8722;</button><span class="qv">'+qty+'</span><button type="button" class="qb" data-id="'+productId+'" data-delta="1">+</button></div>';
}

function renderProds(){
  var el=getEl('prodList');
  var html='';
  if(!el)return;
  if(!PRODS.length){
    el.innerHTML='<div class="no-prods">No items available yet.</div>';
    return;
  }
  for(var i=0;i<PRODS.length;i+=1){
    var product=PRODS[i];
    var qty=cart[product.id]||0;
    var desc=product.description?'<div class="prod-desc">'+esc(product.description)+'</div>':'';
    html+='<div class="prod'+(qty>0?' in-cart':'')+'">'
      +'<div class="prod-info"><div class="prod-name">'+esc(product.name)+'</div>'+desc
      +'<div class="prod-price">'+fmt(product.price)+'</div></div>'
      +renderQtyControls(product.id,qty)
      +'</div>';
  }
  el.innerHTML=html;
}

function updateBar(){
  var items=cartItems();
  var subtotal=cartSubtotal();
  var total=cartTotal();
  var serviceNote=getServiceNote();
  var itemCount=0;
  var box=getEl('orderBox');
  var countText='';
  var html='';

  getEl('cartTotal').textContent=fmt(total);
  for(var i=0;i<items.length;i+=1){
    itemCount+=items[i].qty;
  }
  countText=itemCount>0?(itemCount+' item'+(itemCount===1?'':'s')+' selected'):(serviceNote?'Ready to submit note':'Select items to order');
  getEl('cartCount').textContent=countText;
  getEl('orderBtn').disabled=items.length===0&&!serviceNote;

  if(!box)return;
  if(items.length===0&&serviceNote){
    box.innerHTML='<div class="oi"><span>Order note</span><span>'+esc(serviceNote)+'</span></div>';
    return;
  }

  for(var j=0;j<items.length;j+=1){
    html+='<div class="oi"><span>'+esc(items[j].qty+'× '+items[j].name)+'</span><span>'+fmt(items[j].price*items[j].qty)+'</span></div>';
  }
  html+='<div class="oi"><span>Subtotal</span><span>'+fmt(subtotal)+'</span></div>';
  html+='<div class="ototal"><span>Total</span><span>'+fmt(total)+'</span></div>';
  box.innerHTML=html;
}

function openDrawer(){
  var items=cartItems();
  var serviceNote=getServiceNote();
  var overlay=getEl('drawerOverlay');
  var nameInput=getEl('nameInput');
  if(!items.length&&!serviceNote)return;
  hideError('drawerErr');
  updateBar();
  addClass(overlay,'open');
  setTimeout(function(){if(nameInput&&nameInput.focus)nameInput.focus();},100);
}

function overlayClick(event){
  var overlay=getEl('drawerOverlay');
  if(overlay&&event&&event.target===overlay){
    removeClass(overlay,'open');
  }
}

function postJson(url,payload,onSuccess,onError){
  var xhr=new XMLHttpRequest();
  xhr.open('POST',url,true);
  xhr.setRequestHeader('Content-Type','application/json');
  xhr.onreadystatechange=function(){
    var data={};
    if(xhr.readyState!==4)return;
    try{data=JSON.parse(xhr.responseText||'{}');}catch(parseErr){data={};}
    if(xhr.status>=200&&xhr.status<300){
      onSuccess(data);
      return;
    }
    onError((data&&data.error)||'Something went wrong');
  };
  xhr.onerror=function(){onError('Network error. Please try again.');};
  xhr.send(JSON.stringify(payload));
}

function joinQueue(){
  var nameEl=getEl('nameInput');
  var name=nameEl?String(nameEl.value||'').trim():'';
  var serviceNote=getServiceNote();
  var items=cartItems();
  var btn=getEl('joinBtn');
  var payload={guest_name:name};
  hideError('drawerErr');
  if(!name){showError('drawerErr','Please enter your name.');return;}
  if(!items.length&&!serviceNote){showError('drawerErr','Please select at least one item or enter an order note.');return;}
  if(items.length){
    payload.items=[];
    for(var i=0;i<items.length;i+=1){
      payload.items.push({productId:items[i].id,quantity:items[i].qty});
    }
  }else if(serviceNote){
    payload.product_name=serviceNote;
  }

  btn.disabled=true;
  btn.textContent='Joining...';

  postJson('/api/queues/'+BID+'/join-guest',payload,function(data){
    var ahead=(data&&data.position?data.position:1)-1;
    var totalPrice=data&&data.pricing&&data.pricing.total!=null?Number(data.pricing.total):0;
    var priceNote=totalPrice>0?' • Total: '+fmt(totalPrice):'';
    removeClass(getEl('drawerOverlay'),'open');
    getEl('mainPage').style.display='none';
    getEl('cartBar').style.display='none';
    getEl('successPage').style.display='block';
    getEl('posNum').textContent='#'+(data&&data.position?data.position:1);
    getEl('successSub').innerHTML=(ahead>0?'There '+(ahead===1?'is':'are')+' <strong>'+ahead+'</strong> '+(ahead===1?'person':'people')+' ahead of you.':'You are next!')+'<br><span style="font-size:12px;margin-top:8px;display:block;color:#475569">You will be called when it is your turn.</span>'+priceNote;
  },function(message){
    showError('drawerErr',message);
    btn.disabled=false;
    btn.textContent='Join Queue →';
  });
}

var prodListEl=getEl('prodList');
if(prodListEl){
  prodListEl.addEventListener('click',function(event){
    var target=event.target||event.srcElement;
    var productId,delta;
    while(target&&target!==prodListEl&&!hasClass(target,'qb')){
      target=target.parentNode;
    }
    if(!target||target===prodListEl)return;
    productId=target.getAttribute('data-id');
    delta=parseInt(target.getAttribute('data-delta')||'0',10)||0;
    if(!productId||!delta)return;
    changeQty(productId,delta);
  });
}

if(getEl('serviceNote'))getEl('serviceNote').addEventListener('input',updateBar);
if(getEl('orderBtn'))getEl('orderBtn').addEventListener('click',openDrawer);
if(getEl('joinBtn'))getEl('joinBtn').addEventListener('click',joinQueue);
if(getEl('drawerOverlay'))getEl('drawerOverlay').addEventListener('click',overlayClick);

renderProds();
updateBar();
</script>
</body>
</html>`);
  } catch (e) { res.status(500).send('<h2>Server error</h2>'); }
});

// ──────────────────────────────────────────────────────────────────────────────
// Appointment page — /a/:businessId
// ──────────────────────────────────────────────────────────────────────────────
router.get('/a/:businessId', async (req, res) => {
  try {
    const bId = req.params.businessId;
    const [biz] = await pool.query('SELECT name, address FROM businesses WHERE id = ?', [bId]);
    if (biz.length === 0) return res.status(404).send('<h2>Business not found</h2>');

    const [services] = await pool.query(
      `SELECT id, name, description, price, is_off_sale FROM products WHERE business_id = ? AND is_available = 1 ORDER BY name ASC`,
      [bId]
    );

    const svcs = services.map(s => ({
      id: s.id,
      name: s.name,
      description: s.description || '',
      price: parseFloat(s.price || 0) || 0,
    }));
    const initialServicesHtml = svcs.length === 0
      ? '<div class="no-svcs">No services available yet.</div>'
      : svcs.map((service) => {
          const desc = service.description ? `<div class="svc-desc">${escapeHtml(service.description)}</div>` : '';
          return `<div class="svc" data-service-id="${service.id}"><div class="svc-name">${escapeHtml(service.name)}</div>${desc}<div class="svc-price">${formatMoney(service.price)}</div></div>`;
        }).join('');

    setGuestPageHeaders(res);
    res.send(`<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width,initial-scale=1">
  <meta http-equiv="Cache-Control" content="no-store, no-cache, must-revalidate, max-age=0">
  <meta http-equiv="Pragma" content="no-cache">
  <meta http-equiv="Expires" content="0">
  <title>${biz[0].name} – Book Appointment</title>
  <style>
    *{box-sizing:border-box;margin:0;padding:0}
    body{font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',sans-serif;background:linear-gradient(160deg,#0f172a 0%,#131c2e 100%);color:#f1f5f9;min-height:100vh;display:flex;align-items:flex-start;justify-content:center;padding:20px}
    .card{background:rgba(15,23,42,.92);border-radius:28px;padding:28px;max-width:520px;width:100%;border:1px solid rgba(148,163,184,.15);box-shadow:0 24px 80px rgba(0,0,0,.4)}
    .biz-name{font-size:22px;font-weight:800}
    .biz-addr{color:#64748b;font-size:13px;margin-top:2px;margin-bottom:22px}
    /* Step dots */
    .step-dots{display:flex;align-items:center;gap:8px;margin-bottom:24px}
    .dot{width:8px;height:8px;border-radius:50%;background:rgba(148,163,184,.2);transition:all .3s}
    .dot.active{background:#38bdf8;width:24px;border-radius:4px}
    .dot.done{background:#10b981}
    /* Steps */
    .step{display:none}
    .step.active{display:block}
    .step-title{font-size:18px;font-weight:800;margin-bottom:16px;color:#f1f5f9}
    /* Services */
    .svc{padding:16px;border-radius:16px;border:1px solid rgba(148,163,184,.13);background:rgba(30,41,59,.7);margin-bottom:10px;cursor:pointer;transition:all .15s;touch-action:manipulation}
    .svc:hover,.svc.sel{border-color:#38bdf8;background:rgba(56,189,248,.08)}
    .svc-name{font-size:15px;font-weight:700}
    .svc-desc{color:#94a3b8;font-size:12px;margin-top:3px}
    .svc-price{color:#38bdf8;font-size:13px;font-weight:800;margin-top:6px}
    /* Date pills */
    .date-row{display:flex;gap:8px;overflow-x:auto;padding-bottom:4px;margin-bottom:16px;scrollbar-width:none}
    .date-row::-webkit-scrollbar{display:none}
    .date-pill{flex-shrink:0;padding:10px 14px;border-radius:14px;border:1px solid rgba(148,163,184,.16);background:rgba(30,41,59,.7);cursor:pointer;text-align:center;transition:all .15s;min-width:64px;touch-action:manipulation}
    .date-pill:hover,.date-pill.sel{border-color:#38bdf8;background:rgba(56,189,248,.1);color:#38bdf8}
    .date-pill .dday{font-size:13px;font-weight:700}
    .date-pill .dnum{font-size:11px;opacity:.7;margin-top:2px}
    /* Slots */
    .slots-grid{display:grid;grid-template-columns:repeat(3,1fr);gap:8px;margin-bottom:16px}
    .slot{padding:12px 6px;border-radius:12px;border:1px solid rgba(148,163,184,.15);background:rgba(30,41,59,.7);cursor:pointer;text-align:center;font-size:13px;font-weight:700;transition:all .15s;touch-action:manipulation}
    .slot:hover,.slot.sel{border-color:#38bdf8;background:rgba(56,189,248,.1);color:#38bdf8}
    .slot.booked{opacity:.3;cursor:not-allowed;border-color:transparent}
    .no-slots{color:#475569;font-size:13px;text-align:center;padding:20px 0}
    .loading-txt{color:#475569;font-size:13px;text-align:center;padding:16px 0}
    /* Summary box */
    .summary-box{background:rgba(30,41,59,.7);border:1px solid rgba(148,163,184,.12);border-radius:14px;padding:16px;margin-bottom:16px}
    .sum-row{display:flex;justify-content:space-between;font-size:13px;color:#94a3b8;padding:4px 0}
    .sum-total{display:flex;justify-content:space-between;font-size:16px;font-weight:800;color:#f1f5f9;padding-top:10px;margin-top:6px;border-top:1px solid rgba(148,163,184,.12)}
    /* Form */
    label{font-size:13px;color:#cbd5e1;font-weight:600;display:block;margin-bottom:8px}
    input{width:100%;padding:14px 16px;background:rgba(15,23,42,.85);border:1.5px solid rgba(100,116,139,.25);border-radius:14px;color:#f1f5f9;font-size:16px;outline:none;margin-bottom:14px;transition:border-color .15s}
    input:focus{border-color:#38bdf8}
    /* Buttons */
    .btn{width:100%;padding:15px;background:linear-gradient(135deg,#0ea5e9,#2563eb);border:none;border-radius:14px;color:#fff;font-size:15px;font-weight:700;cursor:pointer;transition:opacity .15s;margin-top:6px;touch-action:manipulation}
    .btn:disabled{opacity:.45;cursor:not-allowed}
    .btn-back{background:rgba(51,65,85,.8);border:1px solid rgba(148,163,184,.18);margin-top:10px}
    /* Error / Success */
    .err{background:rgba(239,68,68,.1);color:#f87171;padding:12px;border-radius:10px;font-size:13px;margin-bottom:12px;display:none}
    .success{display:none;text-align:center;padding:28px 0}
    .success-icon{font-size:56px;margin-bottom:12px}
    .success-title{font-size:24px;font-weight:800;color:#10b981;margin-bottom:8px}
    .success-detail{color:#64748b;font-size:14px;line-height:1.7}
    .no-svcs{color:#475569;text-align:center;padding:40px 0;font-size:14px}
  </style>
</head>
<body>
<div class="card">
  <div class="biz-name">${biz[0].name}</div>
  <div class="biz-addr">${biz[0].address || 'Appointment Booking'}</div>

  <div class="step-dots" id="dots">
    <div class="dot active" id="d0"></div>
    <div class="dot" id="d1"></div>
    <div class="dot" id="d2"></div>
  </div>

  <div class="err" id="globalErr"></div>
  <div class="success" id="successBox">
    <div class="success-icon">✓</div>
    <div class="success-title">Appointment Confirmed!</div>
    <div class="success-detail" id="successDetail"></div>
  </div>

  <!-- Step 0: Service -->
  <div class="step active" id="step0">
    <div class="step-title">Select a Service</div>
    <div id="svcList">${initialServicesHtml}</div>
  </div>

  <!-- Step 1: Date + Slot -->
  <div class="step" id="step1">
    <div class="step-title">Choose a Date &amp; Time</div>
    <div class="date-row" id="dateRow"></div>
    <div id="slotsContainer"><div class="no-slots">Select a date above.</div></div>
    <button type="button" class="btn btn-back" id="backToServicesBtn">&larr; Back</button>
  </div>

  <!-- Step 2: Name + Confirm -->
  <div class="step" id="step2">
    <div class="step-title">Almost There</div>
    <div class="summary-box" id="summaryBox"></div>
    <label for="guestName">Your Name</label>
    <input id="guestName" type="text" placeholder="Enter your name" autocomplete="name">
    <button type="button" class="btn" id="confirmBtn">Confirm Booking &rarr;</button>
    <button type="button" class="btn btn-back" id="backToSlotsBtn">&larr; Back</button>
  </div>
</div>
<script>
var BID=${JSON.stringify(bId)};
var SVCS=${JSON.stringify(svcs)};
var selSvc=null,selDate=null,selSlot=null,currentSlots=[];

function getEl(id){return document.getElementById(id);}
function esc(v){return String(v == null ? '' : v).replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;');}
function fmt(v){return '$'+Number(v||0).toFixed(2);}
function pad2(v){v=parseInt(v,10)||0;return v<10?'0'+v:String(v);}
function hasClass(el,className){return !!el&&(' '+(el.className||'')+' ').indexOf(' '+className+' ')!==-1;}
function isBooked(slot){return !!(slot&&(slot.is_booked===1||slot.is_booked===true||slot.is_booked==='1'));}
function hideGlobalError(){var errEl=getEl('globalErr');if(!errEl)return;errEl.textContent='';errEl.style.display='none';}
function showGlobalError(message){var errEl=getEl('globalErr');if(!errEl)return;errEl.textContent=message;errEl.style.display='block';}

function toLocalDateKey(dateObj){
  return dateObj.getFullYear()+'-'+pad2(dateObj.getMonth()+1)+'-'+pad2(dateObj.getDate());
}

function findService(serviceId){
  for(var i=0;i<SVCS.length;i+=1){
    if(SVCS[i].id===serviceId)return SVCS[i];
  }
  return null;
}

function findSlot(slotId){
  for(var i=0;i<currentSlots.length;i+=1){
    if(currentSlots[i].id===slotId)return currentSlots[i];
  }
  return null;
}

function formatClock(value){
  var dateObj=new Date(value);
  var hours=dateObj.getHours();
  var minutes=pad2(dateObj.getMinutes());
  return pad2(hours)+':'+minutes;
}

function formatHumanTime(value){
  var dateObj=new Date(value);
  var hours=dateObj.getHours();
  var minutes=pad2(dateObj.getMinutes());
  return (hours%12||12)+':'+minutes+' '+(hours<12?'AM':'PM');
}

function gotoStep(stepIndex){
  for(var i=0;i<3;i+=1){
    getEl('step'+i).className='step'+(i===stepIndex?' active':'');
    getEl('d'+i).className='dot'+(i<stepIndex?' done':i===stepIndex?' active':'');
  }
}

function renderSvcs(){
  var el=getEl('svcList');
  var html='';
  if(!el)return;
  if(!SVCS.length){
    el.innerHTML='<div class="no-svcs">No services available yet.</div>';
    return;
  }
  for(var i=0;i<SVCS.length;i+=1){
    var service=SVCS[i];
    var desc=service.description?'<div class="svc-desc">'+esc(service.description)+'</div>':'';
    html+='<div class="svc'+(selSvc&&selSvc.id===service.id?' sel':'')+'" data-service-id="'+service.id+'">'
      +'<div class="svc-name">'+esc(service.name)+'</div>'+desc
      +'<div class="svc-price">'+fmt(service.price)+'</div></div>';
  }
  el.innerHTML=html;
}

function selectSvcById(serviceId){
  var service=findService(serviceId);
  if(!service)return;
  selSvc=service;
  selDate=null;
  selSlot=null;
  currentSlots=[];
  hideGlobalError();
  renderSvcs();
  renderDates();
  getEl('slotsContainer').innerHTML='<div class="no-slots">Select a date above.</div>';
  gotoStep(1);
}

function renderDates(){
  var row=getEl('dateRow');
  var days=['Sun','Mon','Tue','Wed','Thu','Fri','Sat'];
  var months=['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
  var today=new Date();
  var html='';
  if(!row)return;
  for(var i=0;i<7;i+=1){
    var dateObj=new Date(today.getFullYear(),today.getMonth(),today.getDate()+i);
    var iso=toLocalDateKey(dateObj);
    var label=i===0?'Today':i===1?'Tomorrow':days[dateObj.getDay()];
    html+='<div class="date-pill'+(selDate===iso?' sel':'')+'" data-date="'+iso+'"><div class="dday">'+label+'</div><div class="dnum">'+months[dateObj.getMonth()]+' '+dateObj.getDate()+'</div></div>';
  }
  row.innerHTML=html;
}

function getJson(url,onSuccess,onError){
  var xhr=new XMLHttpRequest();
  xhr.open('GET',url,true);
  xhr.onreadystatechange=function(){
    var data=[];
    if(xhr.readyState!==4)return;
    try{data=JSON.parse(xhr.responseText||'[]');}catch(parseErr){data=[];}
    if(xhr.status>=200&&xhr.status<300){
      onSuccess(data);
      return;
    }
    onError((data&&data.error)||'Could not load times. Please try again.');
  };
  xhr.onerror=function(){onError('Could not load times. Please try again.');};
  xhr.send();
}

function renderSlots(){
  var cont=getEl('slotsContainer');
  var html='';
  if(!cont)return;
  if(!currentSlots.length){
    cont.innerHTML='<div class="no-slots">No available times for this day.</div>';
    return;
  }
  html='<div class="slots-grid">';
  for(var i=0;i<currentSlots.length;i+=1){
    var slot=currentSlots[i];
    var booked=isBooked(slot);
    var selected=selSlot&&selSlot.id===slot.id;
    html+='<div class="slot'+(booked?' booked':selected?' sel':'')+'"'+(booked?'':' data-slot-id="'+slot.id+'"')+'>'+formatClock(slot.start_time)+'</div>';
  }
  html+='</div>';
  cont.innerHTML=html;
}

function selectDate(dateKey){
  selDate=dateKey;
  selSlot=null;
  currentSlots=[];
  hideGlobalError();
  renderDates();
  getEl('slotsContainer').innerHTML='<div class="loading-txt">Loading available times...</div>';
  getJson('/api/appointments/slots?businessId='+encodeURIComponent(BID)+'&date='+encodeURIComponent(dateKey)+'&availableOnly=1',function(slots){
    currentSlots=Array.isArray(slots)?slots:[];
    renderSlots();
  },function(message){
    currentSlots=[];
    getEl('slotsContainer').innerHTML='<div class="no-slots">'+esc(message)+'</div>';
  });
}

function selectSlotById(slotId){
  var slot=findSlot(slotId);
  if(!slot||isBooked(slot))return;
  selSlot=slot;
  renderSlots();
  setTimeout(function(){showConfirm();},120);
}

function showConfirm(){
  var dateBits,displayDate,dateStr;
  if(!selSvc||!selDate||!selSlot)return;
  dateBits=selDate.split('-');
  displayDate=new Date(parseInt(dateBits[0],10),parseInt(dateBits[1],10)-1,parseInt(dateBits[2],10));
  dateStr=['Sunday','Monday','Tuesday','Wednesday','Thursday','Friday','Saturday'][displayDate.getDay()]+', '
    +['January','February','March','April','May','June','July','August','September','October','November','December'][displayDate.getMonth()]+' '
    +displayDate.getDate();
  getEl('summaryBox').innerHTML=
    '<div class="sum-row"><span>Service</span><span>'+esc(selSvc.name)+'</span></div>'
    +'<div class="sum-row"><span>Date</span><span>'+dateStr+'</span></div>'
    +'<div class="sum-row"><span>Time</span><span>'+formatHumanTime(selSlot.start_time)+'</span></div>'
    +'<div class="sum-total"><span>Price</span><span>'+fmt(selSvc.price)+'</span></div>';
  gotoStep(2);
  setTimeout(function(){if(getEl('guestName')&&getEl('guestName').focus)getEl('guestName').focus();},100);
}

function postJson(url,payload,onSuccess,onError){
  var xhr=new XMLHttpRequest();
  xhr.open('POST',url,true);
  xhr.setRequestHeader('Content-Type','application/json');
  xhr.onreadystatechange=function(){
    var data={};
    if(xhr.readyState!==4)return;
    try{data=JSON.parse(xhr.responseText||'{}');}catch(parseErr){data={};}
    if(xhr.status>=200&&xhr.status<300){
      onSuccess(data);
      return;
    }
    onError((data&&data.error)||'Booking failed. Please try again.');
  };
  xhr.onerror=function(){onError('Network error. Please try again.');};
  xhr.send(JSON.stringify(payload));
}

function confirmBooking(){
  var guestName=getEl('guestName')?String(getEl('guestName').value||'').trim():'';
  var btn=getEl('confirmBtn');
  hideGlobalError();
  if(!guestName){showGlobalError('Please enter your name.');return;}
  if(!selSvc||!selSlot){showGlobalError('Please select a service and time slot.');return;}
  btn.disabled=true;
  btn.textContent='Booking...';
  postJson('/api/appointments/guest',{
    business_id:BID,
    guest_name:guestName,
    service_id:selSvc.id,
    service_name:selSvc.name,
    slot_id:selSlot.id,
    date_time:selSlot.start_time
  },function(){
    getEl('step0').style.display='none';
    getEl('step1').style.display='none';
    getEl('step2').style.display='none';
    getEl('dots').style.display='none';
    getEl('successBox').style.display='block';
    getEl('successDetail').innerHTML=
      '<strong>'+esc(selSvc.name)+'</strong><br>'
      +selDate+' at '+formatHumanTime(selSlot.start_time)+'<br>'
      +'<span style="color:#38bdf8;font-weight:700">'+fmt(selSvc.price)+'</span>';
  },function(message){
    showGlobalError(message);
    btn.disabled=false;
    btn.textContent='Confirm Booking →';
  });
}

var svcListEl=getEl('svcList');
if(svcListEl){
  svcListEl.addEventListener('click',function(event){
    var target=event.target||event.srcElement;
    while(target&&target!==svcListEl&&!hasClass(target,'svc')){target=target.parentNode;}
    if(!target||target===svcListEl)return;
    selectSvcById(target.getAttribute('data-service-id'));
  });
}

var dateRowEl=getEl('dateRow');
if(dateRowEl){
  dateRowEl.addEventListener('click',function(event){
    var target=event.target||event.srcElement;
    while(target&&target!==dateRowEl&&!hasClass(target,'date-pill')){target=target.parentNode;}
    if(!target||target===dateRowEl)return;
    selectDate(target.getAttribute('data-date'));
  });
}

var slotsContainerEl=getEl('slotsContainer');
if(slotsContainerEl){
  slotsContainerEl.addEventListener('click',function(event){
    var target=event.target||event.srcElement;
    while(target&&target!==slotsContainerEl&&!hasClass(target,'slot')){target=target.parentNode;}
    if(!target||target===slotsContainerEl||hasClass(target,'booked'))return;
    selectSlotById(target.getAttribute('data-slot-id'));
  });
}

if(getEl('backToServicesBtn'))getEl('backToServicesBtn').addEventListener('click',function(){gotoStep(0);});
if(getEl('backToSlotsBtn'))getEl('backToSlotsBtn').addEventListener('click',function(){gotoStep(1);});
if(getEl('confirmBtn'))getEl('confirmBtn').addEventListener('click',confirmBooking);

renderSvcs();
</script>
</body>
</html>`);
  } catch (e) { res.status(500).send('<h2>Server error</h2>'); }
});

module.exports = router;
