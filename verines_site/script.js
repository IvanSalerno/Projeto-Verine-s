const menuToggle = document.querySelector('.menu-toggle');
const nav = document.querySelector('.nav-links');
menuToggle.addEventListener('click', () => {
  const isOpen = nav.classList.toggle('open');
  menuToggle.setAttribute('aria-expanded', String(isOpen));
  menuToggle.setAttribute('aria-label', isOpen ? 'Fechar menu' : 'Abrir menu');
});
nav.querySelectorAll('a').forEach(link => link.addEventListener('click', () => {
  nav.classList.remove('open'); menuToggle.setAttribute('aria-expanded', 'false');
  menuToggle.setAttribute('aria-label', 'Abrir menu');
}));
document.querySelector('#year').textContent = new Date().getFullYear();
const images = {
  hero: "Fotografias do Verine's/verine's cenario_20261104_103142_0000.png",
  restaurant: "Fotografias do Verine's/IMG-20261103-WA0031.jpg",

  'gallery-1': "Fotografias do Verine's/IMG-20261103-WA0028.jpg",
  'gallery-2': "Fotografias do Verine's/IMG-20261103-WA0029.jpg",
  'gallery-3': "Fotografias do Verine's/IMG-20261103-WA0032.jpg",
  'gallery-4': "Fotografias do Verine's/IMG-20261103-WA0036.jpg",
  'gallery-5': "Fotografias do Verine's/IMG-20261103-WA0037.jpg",
  'gallery-6': "Fotografias do Verine's/IMG-20261103-WA0147.jpg",
  'gallery-7': "Fotografias do Verine's/IMG-20261103-WA0148.jpg",
  'gallery-8': "Fotografias do Verine's/IMG-20261103-WA0150.jpg",
  'gallery-9': "Fotografias do Verine's/IMG-20261103-WA0151.jpg",
  'gallery-10': "Fotografias do Verine's/IMG-20261103-WA0152.jpg",
  'gallery-11': "Fotografias do Verine's/IMG-20261103-WA0153.jpg",

  story: "Fotografias do Verine's/IMG-20261103-WA0037.jpg"
};
Object.entries(images).forEach(([key, src]) => {
  if (!src) return;
  const el = document.querySelector(`[data-image="${key}"]`);
  if (!el) return;
  el.style.backgroundImage = `linear-gradient(#24150a22,#24150a22),url("${src}")`;
  el.style.backgroundSize = 'cover'; el.style.backgroundPosition = 'center';
  const placeholder = el.querySelector('.placeholder-content');
  const label = el.querySelector('.image-label');
  if (placeholder) placeholder.style.display = 'none';
  if (label) label.style.display = 'none';
});
const lightbox = document.querySelector('.lightbox');
const lightboxImage = lightbox.querySelector('img');
document.querySelectorAll('.gallery-tile').forEach(tile => tile.addEventListener('click', () => {
  const src = images[tile.dataset.image];
  if (!src) { const small = tile.querySelector('small'); if (small) small.textContent = 'Imagem será adicionada depois'; return; }
  lightboxImage.src = src; lightboxImage.alt = tile.getAttribute('aria-label') || 'Captura do jogo Verine’s';
  lightbox.showModal();
}));
document.querySelector('.lightbox-close').addEventListener('click', () => lightbox.close());
lightbox.addEventListener('click', event => { if (event.target === lightbox) lightbox.close(); });

const downloadButton = document.querySelector("#download-button");
const downloadStatus = document.querySelector("#download-status");
const downloadNote = document.querySelector("#download-note");

// Deixe vazio enquanto o jogo não estiver exportado.
const gameFile = "";

if (gameFile !== "") {
    downloadButton.href = gameFile;
    downloadButton.setAttribute("download", "");
    downloadButton.setAttribute("aria-disabled", "false");

    downloadStatus.textContent = "Download disponível";
    downloadNote.textContent =
        "Clique no botão para baixar o jogo.";

    downloadButton.addEventListener("click", (event) => {
        if (downloadButton.getAttribute("aria-disabled") === "true") {
            event.preventDefault();
        }
    });
} else {
    downloadButton.addEventListener("click", (event) => {
        event.preventDefault();

        downloadNote.textContent =
            "O download será liberado quando o jogo estiver disponível.";
    });
}
