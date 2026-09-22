// ==========================================================================
// SARTAROSHXONA - WEB ECOSYSTEM CORE CONTROLLER (Vanilla JS)
// ==========================================================================

const PLAY_STORE_URL = "https://play.google.com/store/apps/details?id=uz.sartaroshxona.app";
const APP_DEEP_LINK = "sartaroshxona://";

// Fallback curated barbers data
const DEMO_BARBERS = [
  {
    id: 1,
    name: "Farrux Zokirov",
    salon_name: "Royal Barber Club",
    avatar: "https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=200&h=200&fit=crop&crop=face",
    rating: 5.0,
    reviews: 142,
    price: 60000,
    is_open: true,
    is_vip: true,
    address: "Toshkent, Chilonzor 9-mavze",
    specialty: "Fade, Klassik, Soqol parvarishi"
  },
  {
    id: 2,
    name: "Bobur Aliyev",
    salon_name: "Gentlemen's Quarters",
    avatar: "https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=200&h=200&fit=crop&crop=face",
    rating: 4.9,
    reviews: 98,
    price: 50000,
    is_open: true,
    is_vip: false,
    address: "Toshkent, Yunusobod 4-mavze",
    specialty: "Crop Cut, Zamonaviy soch olish"
  },
  {
    id: 3,
    name: "Jasur Rahimov",
    salon_name: "Boroda Barber & Spa",
    avatar: "https://images.unsplash.com/photo-1492562080023-ab3db95bfbce?w=200&h=200&fit=crop&crop=face",
    rating: 4.8,
    reviews: 115,
    price: 75000,
    is_open: false,
    is_vip: true,
    address: "Toshkent, Mirzo Ulug'bek",
    specialty: "Premium soqol stilistikasi"
  },
  {
    id: 4,
    name: "Otabek Saidov",
    salon_name: "Platinum Hair Studio",
    avatar: "https://images.unsplash.com/photo-1519085360753-af0119f7cbe7?w=200&h=200&fit=crop&crop=face",
    rating: 4.9,
    reviews: 210,
    price: 90000,
    is_open: true,
    is_vip: true,
    address: "Toshkent, Mirobod tumani",
    specialty: "Eksklyuziv stillar va bo'yash"
  },
  {
    id: 5,
    name: "Sardor Ahmedov",
    salon_name: "Modern Cut Tashkent",
    avatar: "https://images.unsplash.com/photo-1506794778202-cad84cf45f1d?w=200&h=200&fit=crop&crop=face",
    rating: 4.7,
    reviews: 84,
    price: 45000,
    is_open: true,
    is_vip: false,
    address: "Toshkent, Shayxontohur tumani",
    specialty: "Tezkor va aniq erkaklar turmagi"
  },
  {
    id: 6,
    name: "Shohrux Mirzayev",
    salon_name: "Old School Barbershop",
    avatar: "https://images.unsplash.com/photo-1522075469751-3a6694fb2f61?w=200&h=200&fit=crop&crop=face",
    rating: 4.9,
    reviews: 167,
    price: 65000,
    is_open: true,
    is_vip: true,
    address: "Toshkent, Yakkasaroy tumani",
    specialty: "Klassik ustarada qirish, Soqol"
  }
];

// Trending Hairstyles catalog
const HAIRSTYLES = [
  {
    name: "Low & Mid Skin Fade",
    category: "Zamonaviy Fade",
    price: "60,000 so'm",
    duration: "40 min",
    desc: "Yon qismlari silliq o'tgan, tepasi tabiiy hajmda qoldirilgan eng ommabop yoshlar turmagi.",
    img: "https://images.unsplash.com/photo-1622286342621-4bd786c2447c?w=400&fit=crop"
  },
  {
    name: "Textured French Crop",
    category: "Teksturali Stil",
    price: "55,000 so'm",
    duration: "35 min",
    desc: "Qisqa, parvarish qilish oson va old tomoni to'g'ri chiziqli teksturali yevropacha uslub.",
    img: "https://images.unsplash.com/photo-1503951914875-452162b0f3f1?w=400&fit=crop"
  },
  {
    name: "Classic Pompadour",
    category: "Klassik / Retro",
    price: "70,000 so'm",
    duration: "45 min",
    desc: "Klassik kostyum va jiddiy obraz uchun ideal orqaga taralgan aristokratik hajm.",
    img: "https://images.unsplash.com/photo-1517832606589-715753d4f323?w=400&fit=crop"
  },
  {
    name: "Royal Beard Styling",
    category: "Soqol Dizayni",
    price: "40,000 so'm",
    duration: "25 min",
    desc: "Issiq sochiq va maxsus yog'lar yordamida aniq konturli soqol tekislash.",
    img: "https://images.unsplash.com/photo-1621605815971-fbc98d665033?w=400&fit=crop"
  }
];

let allBarbers = [];
let currentFilter = 'all';
let currentLang = localStorage.getItem('sartaroshxona_lang') || 'uz';

// --------------------------------------------------------------------------
// INITIALIZATION
// --------------------------------------------------------------------------
document.addEventListener('DOMContentLoaded', () => {
  initLanguage();
  initBarbers();
  initHairstyles();
  initCalculator();
  initEcosystemTabs();
  initModals();
});

// --------------------------------------------------------------------------
// LANGUAGE SYSTEM
// --------------------------------------------------------------------------
function initLanguage() {
  const select = document.getElementById('langSelect');
  if (select) {
    select.value = currentLang;
    select.addEventListener('change', (e) => {
      currentLang = e.target.value;
      localStorage.setItem('sartaroshxona_lang', currentLang);
      applyTranslations(currentLang);
    });
  }
  applyTranslations(currentLang);
}

function applyTranslations(lang) {
  const dict = translations[lang] || translations.uz;
  document.querySelectorAll('[data-i18n]').forEach((el) => {
    const key = el.getAttribute('data-i18n');
    if (dict[key]) {
      if (el.tagName === 'INPUT' && el.getAttribute('placeholder')) {
        el.setAttribute('placeholder', dict[key]);
      } else {
        el.textContent = dict[key];
      }
    }
  });
}

// --------------------------------------------------------------------------
// BARBERS EXPLORER & LIVE API
// --------------------------------------------------------------------------
async function initBarbers() {
  const grid = document.getElementById('barbersGrid');
  if (!grid) return;

  try {
    const res = await fetch('/barbers');
    if (res.ok) {
      const data = await res.json();
      if (Array.isArray(data) && data.length > 0) {
        allBarbers = data.map(b => ({
          id: b.id,
          name: b.name || "Sartarosh",
          salon_name: b.salon_name || "Sartaroshxona",
          avatar: b.avatar ? (b.avatar.startsWith('http') ? b.avatar : `/uploads/avatars/${b.avatar}`) : DEMO_BARBERS[0].avatar,
          rating: b.rating || 4.9,
          reviews: b.reviews_count || 45,
          price: b.price || 50000,
          is_open: true,
          is_vip: b.is_vip || false,
          address: b.address || "Toshkent shahri",
          specialty: b.specialty || "Klassik va zamonaviy turmaklar"
        }));
      } else {
        allBarbers = DEMO_BARBERS;
      }
    } else {
      allBarbers = DEMO_BARBERS;
    }
  } catch (err) {
    console.log("Using demo barbers:", err);
    allBarbers = DEMO_BARBERS;
  }

  renderBarbers(allBarbers);

  // Search filter
  const searchInput = document.getElementById('barberSearchInput');
  if (searchInput) {
    searchInput.addEventListener('input', (e) => {
      const q = e.target.value.toLowerCase().trim();
      const filtered = allBarbers.filter(b => 
        b.name.toLowerCase().includes(q) || 
        b.salon_name.toLowerCase().includes(q) ||
        b.specialty.toLowerCase().includes(q)
      );
      renderBarbers(filtered);
    });
  }

  // Tags filter
  document.querySelectorAll('.filter-btn').forEach(btn => {
    btn.addEventListener('click', (e) => {
      document.querySelectorAll('.filter-btn').forEach(b => b.classList.remove('active'));
      e.target.classList.add('active');
      currentFilter = e.target.getAttribute('data-filter');
      applyFilter();
    });
  });
}

function applyFilter() {
  let list = allBarbers;
  if (currentFilter === 'open') {
    list = list.filter(b => b.is_open);
  } else if (currentFilter === 'vip') {
    list = list.filter(b => b.is_vip);
  }
  renderBarbers(list);
}

function renderBarbers(list) {
  const grid = document.getElementById('barbersGrid');
  if (!grid) return;

  if (list.length === 0) {
    grid.innerHTML = `
      <div style="grid-column: 1/-1; text-align: center; padding: 40px; color: var(--text-muted);">
        <p>Qidiruv bo'yicha hech qanday sartarosh topilmadi.</p>
      </div>
    `;
    return;
  }

  grid.innerHTML = list.map(b => `
    <div class="barber-card">
      <div class="barber-header">
        <div class="barber-avatar-wrap">
          <img src="${b.avatar}" alt="${b.name}" class="barber-avatar" onerror="this.src='${DEMO_BARBERS[0].avatar}'">
          ${b.is_open ? '<span class="barber-status-dot" title="Hozir ochiq"></span>' : ''}
        </div>
        <div class="barber-info">
          <h4>${b.name}</h4>
          <div class="barber-salon"><i class="fas fa-store"></i> ${b.salon_name}</div>
        </div>
      </div>
      <p style="font-size: 0.85rem; color: var(--text-muted); margin-bottom: 12px;"><i class="fas fa-cut" style="color: var(--primary-light);"></i> ${b.specialty}</p>
      <div class="barber-metrics">
        <div class="barber-rating"><i class="fas fa-star"></i> ${b.rating} <span>(${b.reviews})</span></div>
        <div class="barber-price">Narxi: <strong>${b.price.toLocaleString()} so'm</strong>dan</div>
      </div>
      <button class="btn btn-primary btn-book" onclick="openBookingModal(${b.id}, '${b.name}', '${b.salon_name}')">
        <i class="fas fa-calendar-check"></i> Navbat olish
      </button>
    </div>
  `).join('');
}

// --------------------------------------------------------------------------
// HAIRSTYLES LOOKBOOK
// --------------------------------------------------------------------------
function initHairstyles() {
  const grid = document.getElementById('stylesGrid');
  if (!grid) return;

  grid.innerHTML = HAIRSTYLES.map(s => `
    <div class="style-card">
      <div class="style-img-wrap">
        <img src="${s.img}" alt="${s.name}">
        <span class="style-tag">${s.category}</span>
      </div>
      <div class="style-body">
        <h4>${s.name}</h4>
        <p>${s.desc}</p>
        <div class="style-footer">
          <span class="style-price">${s.price}</span>
          <span style="color: var(--text-dim); font-size: 0.8rem;"><i class="far fa-clock"></i> ${s.duration}</span>
        </div>
      </div>
    </div>
  `).join('');
}

// --------------------------------------------------------------------------
// EARNINGS CALCULATOR
// --------------------------------------------------------------------------
function initCalculator() {
  const clientsSlider = document.getElementById('calcClients');
  const priceSlider = document.getElementById('calcPrice');
  if (!clientsSlider || !priceSlider) return;

  function update() {
    const clients = parseInt(clientsSlider.value);
    const price = parseInt(priceSlider.value);

    document.getElementById('clientsVal').textContent = `${clients} ta`;
    document.getElementById('priceVal').textContent = `${price.toLocaleString()} so'm`;

    const workingDays = 26;
    const monthlyRev = clients * price * workingDays;
    const timeSavedHours = Math.round((clients * 12 * workingDays) / 60); // 12 mins saved per client
    const growthRev = Math.round(monthlyRev * 0.28); // 28% growth from online bookings

    document.getElementById('calcMonthlyRev').textContent = `${monthlyRev.toLocaleString()} so'm`;
    document.getElementById('calcTimeSaved').textContent = `${timeSavedHours} soat / oy`;
    document.getElementById('calcBonusRev').textContent = `+${growthRev.toLocaleString()} so'm`;
  }

  clientsSlider.addEventListener('input', update);
  priceSlider.addEventListener('input', update);
  update();
}

// --------------------------------------------------------------------------
// ECOSYSTEM TABS
// --------------------------------------------------------------------------
function initEcosystemTabs() {
  const tabs = document.querySelectorAll('.eco-tab-btn');
  tabs.forEach(tab => {
    tab.addEventListener('click', (e) => {
      tabs.forEach(t => t.classList.remove('active'));
      document.querySelectorAll('.eco-content-panel').forEach(p => p.classList.remove('active'));

      const target = tab.getAttribute('data-tab');
      tab.classList.add('active');
      const panel = document.getElementById(target);
      if (panel) panel.classList.add('active');
    });
  });
}

// --------------------------------------------------------------------------
// MODALS & ACTIONS
// --------------------------------------------------------------------------
let selectedBarberForBooking = null;

function initModals() {
  // Booking Form Submit
  const bookingForm = document.getElementById('bookingForm');
  if (bookingForm) {
    bookingForm.addEventListener('submit', (e) => {
      e.preventDefault();
      closeModal('bookingModal');
      showToast("🎉 Navbatingiz muvaffaqiyatli band qilindi! Mobil ilovamizda to'liq tasdiqnoma mavjud.");
    });
  }
}

function openBookingModal(barberId, barberName, salonName) {
  selectedBarberForBooking = { id: barberId, name: barberName, salon: salonName };
  document.getElementById('modalBarberName').textContent = `${barberName} (${salonName})`;
  openModal('bookingModal');
}

function openModal(id) {
  const modal = document.getElementById(id);
  if (modal) modal.classList.add('active');
}

function closeModal(id) {
  const modal = document.getElementById(id);
  if (modal) modal.classList.remove('active');
}

function openQrModal() {
  openModal('qrModal');
}

function redirectToPlayStore() {
  window.open(PLAY_STORE_URL, '_blank');
}

function closeStickyBanner() {
  const banner = document.getElementById('stickyBanner');
  if (banner) banner.style.display = 'none';
}

function showToast(message) {
  const container = document.getElementById('toastContainer');
  if (!container) return;

  const toast = document.createElement('div');
  toast.className = 'toast';
  toast.innerHTML = `<i class="fas fa-check-circle"></i> <span>${message}</span>`;
  container.appendChild(toast);

  setTimeout(() => {
    toast.style.opacity = '0';
    setTimeout(() => toast.remove(), 300);
  }, 4000);
}
