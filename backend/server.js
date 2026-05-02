const express = require('express');
const http = require('http');
const { Server } = require('socket.io');
const cors = require('cors');
require('dotenv').config();

const { testConnection } = require('./db');
const authRoutes = require('./routes/auth');
const businessRoutes = require('./routes/businesses');
const productRoutes = require('./routes/products');
const queueRoutes = require('./routes/queues');
const appointmentRoutes = require('./routes/appointments');
const discountRoutes = require('./routes/discounts');
const analyticsRoutes = require('./routes/analytics');
const historyRoutes = require('./routes/history');
const adminRoutes = require('./routes/admin');
const ticketRoutes = require('./routes/tickets');
const chatRoutes = require('./routes/chats');
const notificationRoutes = require('./routes/notifications');

const app = express();
const server = http.createServer(app);
const PORT = process.env.PORT || 3000;

// Socket.io
const io = new Server(server, {
  cors: { origin: '*', methods: ['GET', 'POST'] }
});

// Make io accessible from routes
app.set('io', io);

io.on('connection', (socket) => {
  socket.on('join:business', (businessId) => {
    socket.join(`business:${businessId}`);
  });
  socket.on('leave:business', (businessId) => {
    socket.leave(`business:${businessId}`);
  });
  socket.on('join:user', (userId) => {
    socket.data.userId = userId;
    socket.join(`user:${userId}`);
  });
  socket.on('leave:user', (userId) => {
    if (socket.data.userId === userId) {
      socket.data.userId = null;
    }
    socket.leave(`user:${userId}`);
  });
  socket.on('join:admin', () => {
    socket.join('admin:panel');
  });
  socket.on('leave:admin', () => {
    socket.leave('admin:panel');
  });
  socket.on('join:chat', (conversationId) => {
    socket.join(`chat:${conversationId}`);
  });
  socket.on('leave:chat', (conversationId) => {
    socket.leave(`chat:${conversationId}`);
  });
});

// Middleware
app.use(cors());
app.use(express.json());

// Request logger
app.use((req, res, next) => {
  console.log(`[${new Date().toISOString()}] ${req.method} ${req.url}`);
  next();
});

// Routes
app.use('/api/auth', authRoutes);
app.use('/api/businesses', businessRoutes);
app.use('/api/products', productRoutes);
app.use('/api/queues', queueRoutes);
app.use('/api/appointments', appointmentRoutes);
app.use('/api/discounts', discountRoutes);
app.use('/api/analytics', analyticsRoutes);
app.use('/api/history', historyRoutes);
app.use('/api/admin', adminRoutes);
app.use('/api/tickets', ticketRoutes);
app.use('/api/chats', chatRoutes);
app.use('/api/notifications', notificationRoutes);

// Test Route
app.get('/api/health', (req, res) => {
  res.json({ status: 'ok', message: 'Queueless API is running' });
});

// New QR guest pages: /q/:businessId (queue) and /a/:businessId (appointment)
// Also overrides /join/:businessId with a redirect to the correct new page
const guestPages = require('./routes/guest_pages');
app.use(guestPages);

// Guest Web Page — served when QR code is scanned (no app needed)
app.get('/join/:businessId', async (req, res) => {
  const { pool } = require('./db');
  try {
    const [biz] = await pool.query('SELECT name, category, address, service_type FROM businesses WHERE id = ?', [req.params.businessId]);
    if (biz.length === 0) return res.status(404).send('<h2>Business not found</h2>');
    const serviceType = biz[0].service_type || 'queue';

    // APPOINTMENT BUSINESSES (barber etc.)
    if (serviceType === 'appointment') {
      const [products] = await pool.query(
        `SELECT id, name, description, price, is_off_sale FROM products WHERE business_id = ? AND is_available = 1 ORDER BY name ASC`,
        [req.params.businessId]
      );
      const serializedServices = products.map(p => ({
        id: p.id,
        name: p.name,
        description: p.description || '',
        price: parseFloat(p.price || 0) || 0,
      }));

      res.send(`<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Book Appointment - ${biz[0].name}</title>
  <style>
    * { box-sizing: border-box; margin: 0; padding: 0; }
    body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif;
           background: linear-gradient(180deg, #0f172a 0%, #111827 100%); color: #fff; min-height: 100vh;
           display: flex; align-items: center; justify-content: center; padding: 20px; }
    .card { background: rgba(15,23,42,0.92); border-radius: 28px; padding: 28px; max-width: 520px; width: 100%;
            border: 1px solid rgba(148,163,184,0.18); box-shadow: 0 24px 80px rgba(0,0,0,0.42); }
    h1 { font-size: 24px; font-weight: 800; margin-bottom: 4px; }
    .sub { color: #6b7280; font-size: 14px; margin-bottom: 24px; }
    label { font-size: 13px; color: #cbd5e1; margin-bottom: 8px; display: block; font-weight: 600; }
    input { width: 100%; padding: 14px 16px; background: rgba(15,23,42,0.8); border: 1px solid rgba(125,211,252,0.18);
            border-radius: 14px; color: #fff; font-size: 15px; outline: none; margin-bottom: 16px; }
    input:focus { border-color: #38bdf8; }
    .btn { width: 100%; padding: 16px; background: linear-gradient(135deg,#0ea5e9,#2563eb);
           border: none; border-radius: 14px; color: #fff; font-size: 16px; font-weight: 700;
           cursor: pointer; transition: opacity 0.2s; margin-top: 8px; }
    .btn:hover { opacity: 0.9; }
    .btn:disabled { opacity: 0.5; cursor: not-allowed; }
    .btn-secondary { background: rgba(51,65,85,0.9); border: 1px solid rgba(148,163,184,0.2); }
    .err { background: rgba(239,68,68,0.1); color: #ef4444; padding: 12px; border-radius: 10px;
           font-size: 13px; margin-bottom: 14px; display: none; }
    .success { background: rgba(16,185,129,0.1); border: 1px solid rgba(16,185,129,0.3);
               color: #10b981; padding: 24px; border-radius: 12px; text-align: center; display: none; }
    .step { display: none; }
    .step.active { display: block; }
    .step-title { font-size: 18px; font-weight: 700; margin-bottom: 18px; color: #f1f5f9; }
    .service-item { padding: 16px; border-radius: 14px; border: 1px solid rgba(148,163,184,0.14);
                    background: rgba(30,41,59,0.72); margin-bottom: 10px; cursor: pointer; transition: all 0.15s; }
    .service-item:hover, .service-item.selected { border-color: #38bdf8; background: rgba(56,189,248,0.08); }
    .service-name { font-size: 15px; font-weight: 700; }
    .service-price { color: #38bdf8; font-size: 13px; font-weight: 700; margin-top: 4px; }
    .service-desc { color: #94a3b8; font-size: 12px; margin-top: 4px; }
    .dates-grid { display: grid; grid-template-columns: repeat(3, 1fr); gap: 10px; margin-bottom: 16px; }
    .date-btn { padding: 12px 8px; border-radius: 12px; border: 1px solid rgba(148,163,184,0.18);
                background: rgba(30,41,59,0.72); cursor: pointer; text-align: center; transition: all 0.15s; font-size: 12px; font-weight: 700; }
    .date-btn:hover, .date-btn.selected { border-color: #38bdf8; background: rgba(56,189,248,0.1); color: #38bdf8; }
    .slots-grid { display: grid; grid-template-columns: repeat(3, 1fr); gap: 8px; margin-bottom: 16px; }
    .slot-btn { padding: 12px 6px; border-radius: 12px; border: 1px solid rgba(148,163,184,0.18);
                background: rgba(30,41,59,0.72); cursor: pointer; text-align: center; font-size: 13px; font-weight: 700; transition: all 0.15s; }
    .slot-btn:hover, .slot-btn.selected { border-color: #38bdf8; background: rgba(56,189,248,0.1); color: #38bdf8; }
    .slot-btn.booked { opacity: 0.35; cursor: not-allowed; border-color: transparent; }
    .summary-box { background: rgba(30,41,59,0.72); border: 1px solid rgba(148,163,184,0.16); border-radius: 14px; padding: 16px; margin-bottom: 16px; font-size: 14px; }
    .summary-row { display: flex; justify-content: space-between; margin-bottom: 8px; color: #94a3b8; }
    .summary-row:last-child { margin-bottom: 0; color: #f1f5f9; font-weight: 700; font-size: 16px; }
    .loading { text-align: center; color: #94a3b8; padding: 20px 0; }
    .step-indicator { display: flex; align-items: center; gap: 8px; margin-bottom: 24px; }
    .step-dot { width: 8px; height: 8px; border-radius: 50%; background: rgba(148,163,184,0.3); }
    .step-dot.active { background: #38bdf8; }
    .step-dot.done { background: #10b981; }
  </style>
</head>
<body>
  <div class="card">
    <h1>${biz[0].name}</h1>
    <p class="sub">${biz[0].address || 'Appointment Booking'}</p>
    <div class="err" id="err"></div>
    <div class="success" id="success">
      <h2 style="font-size:22px;margin-bottom:12px">✓ Appointment Booked!</h2>
      <p id="successDetails" style="color:#6b7280;font-size:14px;line-height:1.6"></p>
    </div>
    <div class="step-indicator" id="stepIndicator">
      <div class="step-dot active" id="dot0"></div>
      <div class="step-dot" id="dot1"></div>
      <div class="step-dot" id="dot2"></div>
      <div class="step-dot" id="dot3"></div>
    </div>
    <div id="mainFlow">
      <!-- Step 0: Name -->
      <div class="step active" id="step0">
        <div class="step-title">Enter Your Name</div>
        <label for="guestName">Your Name</label>
        <input id="guestName" type="text" placeholder="e.g. John Doe" autocomplete="name">
        <button class="btn" onclick="goStep1()">Continue →</button>
      </div>
      <!-- Step 1: Service -->
      <div class="step" id="step1">
        <div class="step-title">Choose a Service</div>
        <div id="serviceList"></div>
        <button class="btn btn-secondary" onclick="showStep(0)" style="margin-top:8px">← Back</button>
      </div>
      <!-- Step 2: Date & Slot -->
      <div class="step" id="step2">
        <div class="step-title">Choose Date & Time</div>
        <label>Date</label>
        <div class="dates-grid" id="dateGrid"></div>
        <label>Available Slots</label>
        <div id="slotsContainer"><div class="loading">Select a date first.</div></div>
        <button class="btn btn-secondary" onclick="showStep(1)" style="margin-top:8px">← Back</button>
      </div>
      <!-- Step 3: Confirm -->
      <div class="step" id="step3">
        <div class="step-title">Confirm Booking</div>
        <div class="summary-box" id="confirmSummary"></div>
        <button class="btn" id="confirmBtn" onclick="confirmBooking()">Confirm Appointment</button>
        <button class="btn btn-secondary" onclick="showStep(2)" style="margin-top:8px">← Back</button>
      </div>
    </div>
  </div>
  <script>
    const businessId = ${JSON.stringify(req.params.businessId)};
    const services = ${JSON.stringify(serializedServices)};
    let selectedService = null;
    let selectedDate = null;
    let selectedSlot = null;
    let guestName = '';

    function escapeHtml(value) {
      return String(value || '').replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;').replace(/"/g,'&quot;');
    }

    function formatMoney(v) { return '$' + Number(v||0).toFixed(2); }

    function showError(msg) { const e=document.getElementById('err'); e.textContent=msg; e.style.display='block'; }
    function hideError() { const e=document.getElementById('err'); e.textContent=''; e.style.display='none'; }

    function showStep(n) {
      for(let i=0;i<4;i++){
        document.getElementById('step'+i).className = 'step' + (i===n?' active':'');
        const dot=document.getElementById('dot'+i);
        if(i<n) dot.className='step-dot done';
        else if(i===n) dot.className='step-dot active';
        else dot.className='step-dot';
      }
      hideError();
    }

    function renderServices() {
      const list=document.getElementById('serviceList');
      if(services.length===0){ list.innerHTML='<p style="color:#94a3b8">No services available.</p>'; return; }
      list.innerHTML=services.map(function(s){
        const sel=(selectedService&&selectedService.id===s.id)?'selected':'';
        const desc=s.description?('<div class="service-desc">'+escapeHtml(s.description)+'</div>'):'';
        const data=JSON.stringify(s).replace(/"/g,'&quot;');
        return '<div class="service-item '+sel+'" onclick="selectService('+data+')">'
          +'<div class="service-name">'+escapeHtml(s.name)+'</div>'
          +desc
          +'<div class="service-price">'+formatMoney(s.price)+'</div>'
          +'</div>';
      }).join('');
    }

    function selectService(s) {
      selectedService = s;
      renderServices();
      selectedDate = null; selectedSlot = null;
      renderDates();
      showStep(2);
    }

    function renderDates() {
      const grid=document.getElementById('dateGrid');
      const today=new Date(); const days=['Sun','Mon','Tue','Wed','Thu','Fri','Sat'];
      const months=['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
      let html='';
      for(let i=0;i<7;i++){
        const d=new Date(today); d.setDate(today.getDate()+i);
        const iso=d.toISOString().split('T')[0];
        const label=(i===0?'Today':i===1?'Tomorrow':days[d.getDay()]);
        const sub=d.getDate()+' '+months[d.getMonth()];
        const sel=selectedDate===iso;
        html+='<div class="date-btn'+(sel?' selected':'')+'" onclick="selectDate(\''+iso+'\')">'+label+'<br><span style="font-weight:400;opacity:0.7">'+sub+'</span></div>';
      }
      grid.innerHTML=html;
    }

    async function selectDate(dateStr) {
      selectedDate=dateStr; selectedSlot=null;
      renderDates();
      const container=document.getElementById('slotsContainer');
      container.innerHTML='<div class="loading">Loading slots...</div>';
      try {
        const r=await fetch('/api/appointments/slots?businessId='+businessId+'&date='+dateStr);
        const slots=await r.json();
        if(!Array.isArray(slots)||slots.length===0){ container.innerHTML='<div class="loading">No slots available for this day.</div>'; return; }
        container.innerHTML='<div class="slots-grid">'+slots.map(sl=>{
          const t=new Date(sl.start_time);
          const h=t.getHours().toString().padStart(2,'0')+':'+t.getMinutes().toString().padStart(2,'0');
          const booked=sl.is_booked;
          const selCls=(selectedSlot&&selectedSlot.id===sl.id)?' selected':'';
          const bookedCls=booked?' booked':'';
          const clickAttr=booked?'':'onclick="selectSlot('+JSON.stringify(sl).replace(/"/g,'&quot;')+')"';
          return '<div class="slot-btn'+selCls+bookedCls+'" '+clickAttr+'>'+h+'</div>';
        }).join('')+'</div>';
      } catch(e){ container.innerHTML='<div class="loading">Could not load slots.</div>'; }
    }

    function selectSlot(slot) {
      if(slot.is_booked) return;
      selectedSlot=slot;
      selectDate(selectedDate); // re-render with selection
      setTimeout(()=>showConfirmStep(),100);
    }

    function showConfirmStep() {
      if(!selectedService||!selectedDate||!selectedSlot) return;
      const t=new Date(selectedSlot.start_time);
      const dateLabel=selectedDate;
      const timeLabel=t.getHours().toString().padStart(2,'0')+':'+t.getMinutes().toString().padStart(2,'0');
      document.getElementById('confirmSummary').innerHTML=
        '<div class="summary-row"><span>Name</span><span>'+escapeHtml(guestName)+'</span></div>'+
        '<div class="summary-row"><span>Service</span><span>'+escapeHtml(selectedService.name)+'</span></div>'+
        '<div class="summary-row"><span>Date</span><span>'+escapeHtml(dateLabel)+'</span></div>'+
        '<div class="summary-row"><span>Time</span><span>'+escapeHtml(timeLabel)+'</span></div>'+
        '<div class="summary-row"><span>Total</span><span>'+formatMoney(selectedService.price)+'</span></div>';
      showStep(3);
    }

    function goStep1() {
      const name=document.getElementById('guestName').value.trim();
      if(!name){ showError('Please enter your name.'); return; }
      guestName=name;
      renderServices();
      showStep(1);
    }

    async function confirmBooking() {
      const btn=document.getElementById('confirmBtn');
      btn.disabled=true; btn.textContent='Booking...';
      hideError();
      const t=new Date(selectedSlot.start_time);
      try {
        const r=await fetch('/api/appointments/guest', {
          method:'POST',
          headers:{'Content-Type':'application/json'},
          body:JSON.stringify({
            business_id: businessId,
            guest_name: guestName,
            service_id: selectedService.id,
            service_name: selectedService.name,
            slot_id: selectedSlot.id,
            date_time: selectedSlot.start_time,
          })
        });
        const d=await r.json();
        if(!r.ok) throw new Error(d.error||'Booking failed');
        document.getElementById('mainFlow').style.display='none';
        document.getElementById('stepIndicator').style.display='none';
        const s=document.getElementById('success'); s.style.display='block';
        const dt=new Date(selectedSlot.start_time);
        document.getElementById('successDetails').innerHTML=
          '<strong>'+escapeHtml(selectedService.name)+'</strong><br>'+
          escapeHtml(selectedDate)+' at '+dt.getHours().toString().padStart(2,'0')+':'+dt.getMinutes().toString().padStart(2,'0')+'<br>'+
          'Price: '+formatMoney(selectedService.price);
      } catch(e){ showError(e.message); btn.disabled=false; btn.textContent='Confirm Appointment'; }
    }

    renderDates();
  </script>
</body>
</html>`);
      return;
    }

    // QUEUE BUSINESSES (bakery, repair etc.)
    const [waiting] = await pool.query("SELECT COUNT(*) as cnt FROM queue_entries WHERE business_id = ? AND status = 'waiting'", [req.params.businessId]);
    const [queueRow] = await pool.query('SELECT is_paused FROM queues WHERE business_id = ?', [req.params.businessId]);
    const [products] = await pool.query(
      `SELECT id, name, description, price, stock, duration_minutes
       FROM products
       WHERE business_id = ? AND is_available = 1 AND is_off_sale = 0
       ORDER BY name ASC`,
      [req.params.businessId]
    );
    const [discounts] = await pool.query(
      `SELECT code, type, value, expires_at, max_usage_count, used_count
       FROM discounts
      WHERE business_id = ? AND is_active = 1 AND used_count < max_usage_count AND (expires_at IS NULL OR expires_at > NOW())
       ORDER BY created_at DESC`,
      [req.params.businessId]
    );

    const serializedProducts = products.map((product) => ({
      id: product.id,
      name: product.name,
      description: product.description || '',
      price: parseFloat(product.price || 0) || 0,
      stock: parseInt(product.stock?.toString() || '0', 10) || 0,
      duration_minutes: parseInt(product.duration_minutes?.toString() || '0', 10) || 0,
    }));
    const serializedDiscounts = discounts.map((discount) => ({
      code: discount.code,
      type: discount.type,
      value: parseFloat(discount.value || 0) || 0,
      expires_at: discount.expires_at,
      max_usage_count: parseInt(discount.max_usage_count?.toString() || '0', 10) || 0,
      used_count: parseInt(discount.used_count?.toString() || '0', 10) || 0,
    }));

    const isPaused = queueRow[0]?.is_paused;
    const waitCount = waiting[0].cnt;

    res.send(`<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Join Queue - ${biz[0].name}</title>
  <style>
    * { box-sizing: border-box; margin: 0; padding: 0; }
    body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif;
           background: linear-gradient(180deg, #0f172a 0%, #111827 100%); color: #fff; min-height: 100vh;
           display: flex; align-items: center; justify-content: center; padding: 20px; }
    .card { background: rgba(15, 23, 42, 0.92); border-radius: 28px; padding: 28px; max-width: 760px; width: 100%;
            border: 1px solid rgba(148,163,184,0.18); box-shadow: 0 24px 80px rgba(0,0,0,0.42); }
    h1 { font-size: 24px; font-weight: 800; margin-bottom: 4px; }
    .sub { color: #6b7280; font-size: 14px; margin-bottom: 24px; }
    .badge { display: inline-flex; align-items: center; gap: 6px; background: rgba(56,189,248,0.14);
             color: #7dd3fc; padding: 8px 16px; border-radius: 20px; font-size: 13px; font-weight: 600;
             margin-bottom: 24px; }
    .section { margin-bottom: 20px; }
    label { font-size: 13px; color: #cbd5e1; margin-bottom: 8px; display: block; font-weight: 600; }
    input { width: 100%; padding: 14px 16px; background: rgba(15,23,42,0.8); border: 1px solid rgba(125,211,252,0.18);
            border-radius: 14px; color: #fff; font-size: 15px; outline: none; }
    input:focus { border-color: #38bdf8; }
    button { width: 100%; padding: 16px; background: linear-gradient(135deg,#0ea5e9,#2563eb);
             border: none; border-radius: 14px; color: #fff; font-size: 16px; font-weight: 700;
             cursor: pointer; transition: opacity 0.2s; }
    button:hover { opacity: 0.9; }
    button:disabled { opacity: 0.5; cursor: not-allowed; }
    .paused { background: rgba(245,158,11,0.1); border: 1px solid rgba(245,158,11,0.3);
              color: #f59e0b; padding: 14px; border-radius: 12px; font-size: 14px; text-align: center; }
    .success { background: rgba(16,185,129,0.1); border: 1px solid rgba(16,185,129,0.3);
               color: #10b981; padding: 20px; border-radius: 12px; text-align: center; display: none; }
    .success h2 { font-size: 20px; margin-bottom: 8px; }
    .err { background: rgba(239,68,68,0.1); color: #ef4444; padding: 12px; border-radius: 10px;
           font-size: 13px; margin-bottom: 14px; display: none; }
    .grid { display: grid; gap: 12px; }
    .product { display: grid; grid-template-columns: 1fr auto; gap: 12px; padding: 16px; border-radius: 18px;
               border: 1px solid rgba(148,163,184,0.14); background: rgba(30,41,59,0.72); }
    .productTitle { font-size: 16px; font-weight: 700; margin-bottom: 4px; }
    .productMeta { display: flex; flex-wrap: wrap; gap: 8px; margin-top: 10px; }
    .pill { display: inline-flex; align-items: center; gap: 6px; padding: 6px 10px; border-radius: 999px;
            font-size: 12px; font-weight: 700; background: rgba(51,65,85,0.95); color: #e2e8f0; }
    .muted { color: #94a3b8; font-size: 13px; line-height: 1.5; }
    .qtyBox { display: flex; align-items: center; gap: 10px; }
    .qtyButton { width: 38px; height: 38px; padding: 0; border-radius: 12px; background: rgba(51,65,85,0.96); }
    .qtyValue { min-width: 22px; text-align: center; font-size: 16px; font-weight: 800; }
    .couponWrap { display: flex; flex-wrap: wrap; gap: 8px; margin-top: 10px; }
    .couponChip { width: auto; padding: 10px 12px; border-radius: 999px; font-size: 12px; font-weight: 700;
                  background: rgba(34,197,94,0.12); color: #86efac; border: 1px solid rgba(34,197,94,0.22); }
    .couponChip.active { background: rgba(14,165,233,0.18); color: #7dd3fc; border-color: rgba(14,165,233,0.32); }
    .couponRow { display: grid; grid-template-columns: 1fr auto; gap: 10px; margin-top: 12px; }
    .couponRow button { width: auto; padding: 0 18px; }
    .summary { padding: 18px; border-radius: 20px; background: rgba(15,23,42,0.86); border: 1px solid rgba(148,163,184,0.16); }
    .summaryItems { color: #cbd5e1; font-size: 13px; margin-bottom: 14px; line-height: 1.6; }
    .summaryRow, .summaryTotal { display: flex; justify-content: space-between; align-items: center; }
    .summaryRow { color: #94a3b8; font-size: 14px; margin-bottom: 8px; }
    .summaryTotal { font-size: 18px; font-weight: 800; color: #f8fafc; margin-top: 8px; }
    .hidden { display: none !important; }
    .helper { color: #94a3b8; font-size: 12px; margin-top: 8px; }
    .pay-options { display: grid; grid-template-columns: 1fr 1fr; gap: 10px; margin-bottom: 16px; }
    .pay-btn { padding: 14px; border-radius: 14px; border: 1px solid rgba(148,163,184,0.18); background: rgba(30,41,59,0.72);
               font-size: 13px; font-weight: 700; cursor: pointer; text-align: center; transition: all 0.15s; }
    .pay-btn.selected { border-color: #38bdf8; background: rgba(56,189,248,0.1); color: #38bdf8; }
    @media (max-width: 640px) {
      .card { padding: 20px; }
      .product { grid-template-columns: 1fr; }
      .couponRow { grid-template-columns: 1fr; }
    }
  </style>
</head>
<body>
  <div class="card">
    <h1>${biz[0].name}</h1>
    <p class="sub">${biz[0].address || 'Walk-in Queue'}</p>
    <div class="badge">${waitCount} people waiting</div>
    ${isPaused ? `<div class="paused">Queue is temporarily paused. You can still join and keep your place.</div>` : ''}
    <div class="err" id="err"></div>
    <div class="success" id="success">
      <h2>You are in line</h2>
      <p id="posText"></p>
      <p style="color:#6b7280;font-size:13px;margin-top:8px">Keep this page open to confirm your place.</p>
    </div>
    <form id="form">
      <div class="section">
        <label for="name">Nickname</label>
        <input id="name" type="text" placeholder="Enter the nickname you want to use" autocomplete="nickname" required>
        <p class="helper">Only the nickname is different from the normal shopping flow.</p>
      </div>

      <div class="section ${serializedProducts.length === 0 ? 'hidden' : ''}" id="productSection">
        <label>Products</label>
        <div class="grid" id="productList"></div>
      </div>

      <div class="section ${serializedProducts.length > 0 ? 'hidden' : ''}" id="serviceSection">
        <label for="service">Service or note</label>
        <input id="service" type="text" placeholder="Optional note for the business">
      </div>

      <div class="section ${serializedProducts.length > 0 && serializedDiscounts.length === 0 ? 'hidden' : serializedProducts.length === 0 ? 'hidden' : ''}" id="couponSection">
        <label>Available Coupons</label>
        <div class="couponWrap" id="couponList"></div>
        <div class="couponRow">
          <input id="coupon" type="text" placeholder="Enter coupon code">
          <button type="button" id="couponApply">Apply</button>
        </div>
      </div>

      <div class="section summary ${serializedProducts.length === 0 ? 'hidden' : ''}" id="summarySection">
        <div class="summaryItems" id="summaryItems">No products selected yet.</div>
        <div class="summaryRow">
          <span>Subtotal</span>
          <strong id="subtotal">$0.00</strong>
        </div>
        <div class="summaryRow hidden" id="discountRow">
          <span>Discount</span>
          <strong id="discountAmount">- $0.00</strong>
        </div>
        <div class="summaryTotal">
          <span>Total</span>
          <strong id="total">$0.00</strong>
        </div>
      </div>

      <div class="section" id="paymentSection">
        <label>Payment Method</label>
        <div class="pay-options">
          <div class="pay-btn selected" id="payLaterBtn" onclick="selectPayment('later')">💳 Pay on Arrival</div>
          <div class="pay-btn" id="payNowBtn" onclick="selectPayment('now')">🏦 Pay Now</div>
        </div>
        <p class="helper" id="payHelper">You will pay at the venue when your turn arrives.</p>
      </div>

      <button type="submit" id="btn">Join Queue →</button>
    </form>
  </div>
  <script>
    const businessId = ${JSON.stringify(req.params.businessId)};
    const products = ${JSON.stringify(serializedProducts)};
    const coupons = ${JSON.stringify(serializedDiscounts)};
    const cart = {};
    let appliedDiscount = null;
    let paymentMethod = 'later';

    function selectPayment(method) {
      paymentMethod = method;
      document.getElementById('payLaterBtn').className = 'pay-btn' + (method==='later'?' selected':'');
      document.getElementById('payNowBtn').className = 'pay-btn' + (method==='now'?' selected':'');
      document.getElementById('payHelper').textContent = method === 'now'
        ? 'Payment details will be shared after joining.'
        : 'You will pay at the venue when your turn arrives.';
    }

    function escapeHtml(value) {
      return String(value || '')
        .replace(/&/g, '&amp;')
        .replace(/</g, '&lt;')
        .replace(/>/g, '&gt;')
        .replace(/"/g, '&quot;')
        .replace(/'/g, '&#39;');
    }

    function formatMoney(value) {
      return '$' + Number(value || 0).toFixed(2);
    }

    function formatCoupon(discount) {
      return discount.type === 'percentage'
        ? discount.value.toFixed(0) + '% off'
        : formatMoney(discount.value) + ' off';
    }

    function formatDuration(minutes) {
      const totalMinutes = Number(minutes || 0);
      if (totalMinutes <= 0) return '';
      if (totalMinutes < 60) return totalMinutes + ' min';
      const hours = Math.floor(totalMinutes / 60);
      const remainder = totalMinutes % 60;
      return remainder === 0 ? hours + 'h' : hours + 'h ' + remainder + 'm';
    }

    function showError(message) {
      const errEl = document.getElementById('err');
      errEl.textContent = message;
      errEl.style.display = 'block';
    }

    function hideError() {
      const errEl = document.getElementById('err');
      errEl.textContent = '';
      errEl.style.display = 'none';
    }

    function getCartItems() {
      return products
        .filter(function(product) { return (cart[product.id] || 0) > 0; })
        .map(function(product) {
          return {
            id: product.id,
            name: product.name,
            price: Number(product.price || 0),
            quantity: cart[product.id],
          };
        });
    }

    function getSubtotal() {
      return getCartItems().reduce(function(sum, item) {
        return sum + (item.price * item.quantity);
      }, 0);
    }

    function clearAppliedDiscount(silent) {
      appliedDiscount = null;
      if (!silent) {
        document.getElementById('coupon').value = '';
      }
      renderCoupons();
      renderSummary();
    }

    function changeQty(productId, delta) {
      const product = products.find(function(p) { return p.id === productId; });
      if (!product || product.stock === 0) return;
      const current = cart[productId] || 0;
      const maxQty = product.stock > 0 ? product.stock : 99;
      const next = Math.max(0, Math.min(maxQty, current + delta));
      if (next === 0) {
        delete cart[productId];
      } else {
        cart[productId] = next;
      }

      if (appliedDiscount) {
        clearAppliedDiscount(true);
      }

      renderProducts();
      renderSummary();
    }

    function renderProducts() {
      const container = document.getElementById('productList');
      if (!container) return;

      container.innerHTML = products.map(function(product) {
        const quantity = cart[product.id] || 0;
        const outOfStock = product.stock === 0;
        const description = product.description ? '<p class="muted">' + escapeHtml(product.description) + '</p>' : '';
        const durationLabel = formatDuration(product.duration_minutes);
        const durationPill = durationLabel ? '<span class="pill">' + durationLabel + '</span>' : '';
        const stockBadge = outOfStock ? '<span class="pill" style="background:rgba(239,68,68,0.15);color:#f87171">Out of stock</span>' : '';

        const qtyControls = outOfStock
          ? '<span style="font-size:12px;color:#64748b;padding:8px">Unavailable</span>'
          : '<div class="qtyBox">'
            + '<button class="qtyButton" type="button" onclick="changeQty(\'' + product.id + '\', -1)">-</button>'
            + '<span class="qtyValue">' + quantity + '</span>'
            + '<button class="qtyButton" type="button" onclick="changeQty(\'' + product.id + '\', 1)">+</button>'
            + '</div>';

        return '<div class="product" style="' + (outOfStock ? 'opacity:0.6' : '') + '">'
          + '<div>'
          + '<div class="productTitle">' + escapeHtml(product.name) + '</div>'
          + description
          + '<div class="productMeta">'
          + '<span class="pill">' + formatMoney(product.price) + '</span>'
          + durationPill
          + stockBadge
          + '</div>'
          + '</div>'
          + qtyControls
          + '</div>';
      }).join('');
    }

    function selectCoupon(code) {
      document.getElementById('coupon').value = code;
      applyCoupon();
    }

    function renderCoupons() {
      const list = document.getElementById('couponList');
      if (!list) return;

      const activeCode = appliedDiscount ? document.getElementById('coupon').value.trim().toUpperCase() : '';
      list.innerHTML = coupons.map(function(coupon) {
        const activeClass = activeCode === coupon.code ? ' active' : '';
        return '<button type="button" class="couponChip' + activeClass + '" onclick="selectCoupon(\'' + coupon.code + '\')">'
          + escapeHtml(coupon.code) + ' - ' + escapeHtml(formatCoupon(coupon))
          + '</button>';
      }).join('');
    }

    function renderSummary() {
      const subtotal = getSubtotal();
      const discountAmount = appliedDiscount ? Number(appliedDiscount.discount_amount || 0) : 0;
      const total = Math.max(0, subtotal - discountAmount);
      const items = getCartItems();

      const summaryItems = document.getElementById('summaryItems');
      if (summaryItems) {
        summaryItems.textContent = items.length === 0
          ? 'No products selected yet.'
          : items.map(function(item) { return item.quantity + 'x ' + item.name; }).join(', ');
      }

      const subtotalEl = document.getElementById('subtotal');
      const discountAmountEl = document.getElementById('discountAmount');
      const totalEl = document.getElementById('total');
      const discountRow = document.getElementById('discountRow');
      if (subtotalEl) subtotalEl.textContent = formatMoney(subtotal);
      if (discountAmountEl) discountAmountEl.textContent = '- ' + formatMoney(discountAmount);
      if (totalEl) totalEl.textContent = formatMoney(total);
      if (discountRow) {
        if (discountAmount > 0) discountRow.classList.remove('hidden');
        else discountRow.classList.add('hidden');
      }
    }

    async function applyCoupon() {
      const couponInput = document.getElementById('coupon');
      const code = couponInput.value.trim().toUpperCase();
      const subtotal = getSubtotal();
      const applyButton = document.getElementById('couponApply');

      if (!code) {
        showError('Enter a coupon code first.');
        return;
      }
      if (subtotal <= 0) {
        showError('Select at least one product before applying a coupon.');
        return;
      }

      hideError();
      applyButton.disabled = true;
      applyButton.textContent = 'Applying...';

      try {
        const response = await fetch('/api/discounts/validate', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ businessId: businessId, code: code, amount: subtotal })
        });
        const data = await response.json();
        if (!response.ok) throw new Error(data.error || 'Coupon could not be applied.');

        appliedDiscount = data;
        couponInput.value = code;
        hideError();
      } catch (err) {
        appliedDiscount = null;
        showError(err.message);
      } finally {
        applyButton.disabled = false;
        applyButton.textContent = 'Apply';
        renderCoupons();
        renderSummary();
      }
    }

    document.getElementById('couponApply')?.addEventListener('click', applyCoupon);

    renderProducts();
    renderCoupons();
    renderSummary();

    document.getElementById('form').addEventListener('submit', async (e) => {
      e.preventDefault();
      const btn = document.getElementById('btn');
      btn.disabled = true; btn.textContent = 'Joining...';
      hideError();

      const nickname = document.getElementById('name').value.trim();
      if (!nickname) {
        showError('Please enter a nickname.');
        btn.disabled = false;
        btn.textContent = 'Join Queue →';
        return;
      }

      const payload = { guest_name: nickname, payment_method: paymentMethod };
      if (products.length > 0) {
        const items = getCartItems().map(function(item) {
          return { productId: item.id, quantity: item.quantity };
        });

        if (items.length === 0) {
          showError('Select at least one product before joining the queue.');
          btn.disabled = false;
          btn.textContent = 'Join Queue →';
          return;
        }

        payload.items = items;
        if (appliedDiscount) {
          payload.discountCode = document.getElementById('coupon').value.trim().toUpperCase();
        }
      } else {
        const serviceNote = document.getElementById('service').value.trim();
        if (serviceNote) payload.product_name = serviceNote;
      }

      try {
        const r = await fetch('/api/queues/${req.params.businessId}/join-guest', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify(payload)
        });
        const d = await r.json();
        if (!r.ok) throw new Error(d.error || 'Failed to join');
        document.getElementById('form').style.display = 'none';
        const s = document.getElementById('success');
        s.style.display = 'block';
        const priceText = d.pricing && Number(d.pricing.total || 0) > 0
          ? ' Total: ' + formatMoney(d.pricing.total) + '.'
          : '';
        document.getElementById('posText').textContent = 'Position #' + d.position + ' - ' + (d.position - 1) + ' people ahead of you.' + priceText;
      } catch (err) {
        showError(err.message);
        btn.disabled = false; btn.textContent = 'Join Queue →';
      }
    });
  </script>
</body>
</html>`);
  } catch (err) { res.status(500).send('<h2>Server error</h2>'); }
});

// Global Error Handler
// Global Error Handler
app.use((err, req, res, next) => {
  console.error(err.stack);
  res.status(500).json({ error: 'Something went wrong on the server' });
});

// Default 404
app.use((req, res) => {
  res.status(404).json({ error: 'Route not found' });
});

server.listen(PORT, '0.0.0.0', async () => {
  console.log(`🚀 Queueless Server running on http://0.0.0.0:${PORT} (accessible on LAN)`);
  await testConnection();
});
