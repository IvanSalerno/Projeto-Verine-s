/**
 * script.js — Interações gerais do site (menu, galeria, ano, download).
 * As funções que usam APIs da "Cozinha de Testes" e do contato ficam em cozinha.js.
 */

/* ---------------------------------------------------------------
 * Menu responsivo
 * --------------------------------------------------------------- */
const menuToggle = document.querySelector('.menu-toggle');
const nav = document.querySelector('.nav-links');

function definirMenu(aberto) {
  nav.classList.toggle('open', aberto);
  menuToggle.setAttribute('aria-expanded', String(aberto));
  menuToggle.setAttribute('aria-label', aberto ? 'Fechar menu' : 'Abrir menu');
  menuToggle.textContent = aberto ? '✕' : '☰';
}

menuToggle.addEventListener('click', () => definirMenu(!nav.classList.contains('open')));

nav.querySelectorAll('a').forEach((link) => link.addEventListener('click', () => definirMenu(false)));

// Fecha com Esc ou ao tocar fora do menu (celular)
document.addEventListener('keydown', (evento) => {
  if (evento.key === 'Escape' && nav.classList.contains('open')) {
    definirMenu(false);
    menuToggle.focus();
  }
});
document.addEventListener('click', (evento) => {
  if (nav.classList.contains('open') && !evento.target.closest('.site-header')) definirMenu(false);
});

// Destaca no menu a seção que está visível na tela
const linksMenu = [...nav.querySelectorAll('a[href^="#"]')];
const observador = new IntersectionObserver((itens) => {
  itens.forEach((item) => {
    if (!item.isIntersecting) return;
    linksMenu.forEach((link) => link.classList.toggle('is-current', link.getAttribute('href') === '#' + item.target.id));
  });
}, { rootMargin: '-45% 0px -50% 0px' });
linksMenu.forEach((link) => {
  const secao = document.querySelector(link.getAttribute('href'));
  if (secao) observador.observe(secao);
});

document.querySelector('#year').textContent = new Date().getFullYear();

/* ---------------------------------------------------------------
 * Galeria com lightbox (ampliar, anterior/próxima, teclado)
 * Antes, o caminho das imagens era montado à mão e não existia
 * (faltava "verines_site/"). Agora lemos o src da própria <img>.
 * --------------------------------------------------------------- */
const lightbox = document.querySelector('.lightbox');
const lightboxImage = lightbox.querySelector('img');
const lightboxCaption = lightbox.querySelector('.lightbox-caption');
const tiles = [...document.querySelectorAll('.gallery-tile')];
let indiceAtual = 0;

function mostrarImagem(indice) {
  indiceAtual = (indice + tiles.length) % tiles.length;
  const tile = tiles[indiceAtual];
  const img = tile.querySelector('img');
  lightboxImage.src = img.currentSrc || img.src;
  lightboxImage.alt = tile.getAttribute('aria-label') || "Captura do jogo Verine's";
  lightboxCaption.textContent = `${lightboxImage.alt} · ${indiceAtual + 1} de ${tiles.length}`;
}

tiles.forEach((tile, indice) => tile.addEventListener('click', () => {
  mostrarImagem(indice);
  lightbox.showModal();
}));

lightbox.querySelectorAll('.lightbox-arrow').forEach((botao) => botao.addEventListener('click', () => {
  mostrarImagem(indiceAtual + Number(botao.dataset.direcao));
}));
lightbox.addEventListener('keydown', (evento) => {
  if (evento.key === 'ArrowRight') mostrarImagem(indiceAtual + 1);
  if (evento.key === 'ArrowLeft') mostrarImagem(indiceAtual - 1);
});
lightbox.querySelector('.lightbox-close').addEventListener('click', () => lightbox.close());
lightbox.addEventListener('click', (evento) => { if (evento.target === lightbox) lightbox.close(); });

/* ---------------------------------------------------------------
 * Download do jogo
 * (corrigido: o elemento #download-note não existia e gerava erro)
 * --------------------------------------------------------------- */
const downloadButton = document.querySelector('#download-button');
const downloadStatus = document.querySelector('#download-status');
const downloadNote = document.querySelector('#download-note');

// Caminho do arquivo exportado do jogo
const gameFile = "./verines_site/Verine'sGame.zip";

if (gameFile !== '') {
  downloadButton.href = gameFile;
  downloadButton.setAttribute('download', '');
  downloadButton.setAttribute('aria-disabled', 'false');
  downloadStatus.textContent = 'Download disponível';
  downloadNote.textContent = "Clique no botão acima para baixar o jogo Verine's.";
} else {
  downloadButton.setAttribute('aria-disabled', 'true');
  downloadButton.addEventListener('click', (event) => {
    event.preventDefault();
    downloadNote.textContent = 'O download será liberado quando o jogo estiver disponível.';
  });
}
