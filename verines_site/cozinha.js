/**
 * cozinha.js — Funcionalidades que consomem APIs e montam o DOM dinamicamente.
 *
 *  1. Status do servidor ............ GET  /api/status
 *  2. Abas da Cozinha de Testes ..... (somente DOM)
 *  3. Livro de receitas ............. GET  /api/receitas, GET /api/receitas/:id?porcoes=N
 *     Páginas manchadas ............. GET  /api/desafios/:id, POST /api/desafios/:id/resposta
 *  4. Desafios e ranking ............ POST /api/partidas, GET /api/desafios, POST resposta,
 *                                     GET/POST /api/ranking
 *  5. Mercado do dia ................ AwesomeAPI (cotação do dólar e do euro)
 *  6. Contato ....................... ViaCEP + POST /api/mensagens, GET /api/mensagens/estatisticas
 *  7. Informações do download ....... GET  /api/jogo
 *  8. Monitor de APIs ............... mostra cada requisição feita pela página
 *
 * Depende de window.VerinesAPI (api.js).
 */
(function () {
  'use strict';

  const { verines, externas, monitor } = window.VerinesAPI;

  /* =================================================================
   * Utilitários de DOM e formatação
   * ================================================================= */
  const $ = (seletor, raiz = document) => raiz.querySelector(seletor);
  const $$ = (seletor, raiz = document) => [...raiz.querySelectorAll(seletor)];

  /** Cria um elemento: criar('p', { class: 'x', text: 'Olá' }, filho1, filho2) */
  function criar(tag, props = {}, ...filhos) {
    const el = document.createElement(tag);
    for (const [chave, valor] of Object.entries(props)) {
      if (valor === null || valor === undefined || valor === false) continue;
      if (chave === 'class') el.className = valor;
      else if (chave === 'text') el.textContent = valor;
      else if (chave === 'dataset') Object.assign(el.dataset, valor);
      else if (chave.startsWith('on')) el.addEventListener(chave.slice(2), valor);
      else el.setAttribute(chave, valor === true ? '' : valor);
    }
    filhos.flat().forEach((f) => {
      if (f === null || f === undefined || f === false) return;
      el.append(f instanceof Node ? f : document.createTextNode(String(f)));
    });
    return el;
  }

  const reais = (centavos) => (centavos / 100).toLocaleString('pt-BR', { style: 'currency', currency: 'BRL' });
  const numeroBR = (n, casas = 2) => n.toLocaleString('pt-BR', { maximumFractionDigits: casas });
  const dinheiroBR = (n) => n.toLocaleString('pt-BR', { minimumFractionDigits: 2, maximumFractionDigits: 2 });

  /** Escreve uma mensagem de retorno com cor (ok / erro / info). */
  function mostrarFeedback(el, tipo, texto) {
    el.textContent = texto;
    el.classList.remove('is-ok', 'is-erro', 'is-info');
    if (tipo) el.classList.add('is-' + tipo);
  }

  /** Converte "R$ 12,50", "150 g", "1.234,5" em número (ou null). */
  function lerNumero(texto) {
    let t = String(texto).toLowerCase().replace(/r\$|\s/g, '').replace(/(kg|g|ml|l|un|unidades?)$/, '');
    if (t.includes(',') && t.includes('.')) t = t.replace(/\./g, '').replace(',', '.');
    else t = t.replace(',', '.');
    return /^-?\d+(\.\d+)?$/.test(t) ? Number(t) : null;
  }

  /** Bloco padrão de erro com botão "Tentar novamente". */
  function blocoErro(erro, aoTentar, { externa = false } = {}) {
    const servidorDesligado = erro.tipo === 'rede' || erro.tipo === 'timeout';
    return criar('div', { class: 'api-error', role: 'alert' },
      criar('strong', { text: servidorDesligado ? 'Serviço indisponível no momento' : 'Algo deu errado' }),
      criar('p', { text: erro.message }),
      servidorDesligado && externa
        ? criar('p', { class: 'api-error-help', text: 'Este dado vem de um serviço público na internet. Verifique sua conexão e tente de novo em instantes.' })
        : null,
      servidorDesligado && !externa && estado.servidorOnline === false
        ? criar('p', { class: 'api-error-help' }, 'Para usar esta seção, inicie o servidor do projeto com ',
          criar('code', { text: 'node server/server.js' }), ' e acesse ', criar('code', { text: 'http://localhost:3000' }), '.')
        : null,
      aoTentar ? criar('button', { class: 'button-ghost', type: 'button', text: '↻ Tentar novamente', onclick: aoTentar }) : null);
  }

  /** Estado compartilhado entre os módulos. */
  const estado = { servidorOnline: null };

  /* =================================================================
   * 1. Status do servidor
   * ================================================================= */
  const badges = $$('[data-api-status]');

  async function verificarServidor() {
    badges.forEach((b) => { b.dataset.apiStatus = 'verificando'; b.textContent = 'Verificando servidor…'; });
    try {
      const status = await verines.status();
      estado.servidorOnline = true;
      badges.forEach((b) => {
        b.dataset.apiStatus = 'online';
        b.textContent = `Servidor online · ${status.receitas} receitas · ${status.temasDeDesafio.length} temas`;
      });
    } catch {
      estado.servidorOnline = false;
      badges.forEach((b) => { b.dataset.apiStatus = 'offline'; b.textContent = 'Servidor offline'; });
    }
  }

  /* =================================================================
   * 2. Abas (tabs acessíveis: clique e setas do teclado)
   * ================================================================= */
  const abas = $$('.kitchen-tab');
  const carregadas = new Set();
  const aoAbrirAba = {
    'painel-receitas': () => carregarReceitas(),
    'painel-desafios': () => carregarRanking(),
    'painel-mercado': () => carregarCotacoes(),
  };

  function ativarAba(aba, focar = false) {
    abas.forEach((a) => {
      const ativa = a === aba;
      a.classList.toggle('is-active', ativa);
      a.setAttribute('aria-selected', String(ativa));
      a.tabIndex = ativa ? 0 : -1;
      document.getElementById(a.getAttribute('aria-controls')).hidden = !ativa;
    });
    if (focar) aba.focus();
    const painel = aba.getAttribute('aria-controls');
    if (!carregadas.has(painel)) {
      carregadas.add(painel);
      aoAbrirAba[painel]();
    }
  }

  abas.forEach((aba, i) => {
    aba.addEventListener('click', () => ativarAba(aba));
    aba.addEventListener('keydown', (e) => {
      if (e.key === 'ArrowRight') ativarAba(abas[(i + 1) % abas.length], true);
      if (e.key === 'ArrowLeft') ativarAba(abas[(i - 1 + abas.length) % abas.length], true);
    });
  });

  /* =================================================================
   * 3. Livro de receitas
   * ================================================================= */
  const listaReceitas = $('#lista-receitas');
  const detalheReceita = $('#detalhe-receita');
  const CHAVE_RECUPERADOS = 'verines:recuperados';
  const receitaAtual = { id: null, dados: null, seq: 0 };

  // Dados recuperados ficam salvos no navegador (como o progresso do jogo).
  function lerRecuperados() {
    try { return JSON.parse(localStorage.getItem(CHAVE_RECUPERADOS)) || {}; } catch { return {}; }
  }
  function salvarRecuperado(receita, ingrediente, quantidade) {
    const todos = lerRecuperados();
    todos[receita] = { ...(todos[receita] || {}), [ingrediente]: quantidade };
    try { localStorage.setItem(CHAVE_RECUPERADOS, JSON.stringify(todos)); } catch { /* armazenamento indisponível */ }
  }

  async function carregarReceitas() {
    listaReceitas.replaceChildren(criar('p', { class: 'loading-text', text: 'Carregando o livro de receitas…' }));
    try {
      const { receitas } = await verines.receitas();
      if (!Array.isArray(receitas) || receitas.length === 0) {
        listaReceitas.replaceChildren(criar('p', { text: 'Nenhuma receita encontrada no livro.' }));
        return;
      }
      listaReceitas.replaceChildren(...receitas.map(criarCartaoReceita));
    } catch (erro) {
      listaReceitas.replaceChildren(blocoErro(erro, carregarReceitas));
    }
  }

  function criarCartaoReceita(r) {
    return criar('button', {
      class: 'recipe-item', type: 'button', dataset: { id: r.id }, 'aria-pressed': 'false',
      onclick: () => abrirReceita(r.id),
    },
    criar('span', { class: 'recipe-item-name', text: r.nome }),
    criar('span', { class: 'recipe-item-meta', text: `${r.porcoesBase} porções · ${r.precoPorcaoFormatado}/porção` }),
    criar('span', { class: 'recipe-item-tags' },
      r.temPaginaManchada ? criar('span', { class: 'tag tag-stain', text: 'Página manchada' }) : null,
      r.bloqueada ? criar('span', { class: 'tag tag-secret', text: '🔒 Segredo do vovô' }) : null));
  }

  async function abrirReceita(id) {
    $$('.recipe-item', listaReceitas).forEach((b) => {
      const ativa = b.dataset.id === id;
      b.classList.toggle('is-active', ativa);
      b.setAttribute('aria-pressed', String(ativa));
    });
    await buscarReceita(id, null, true);
  }

  /** Busca a receita (com porções opcionais) e atualiza a tela. */
  async function buscarReceita(id, porcoes, montarDoZero) {
    const seq = ++receitaAtual.seq; // ignora respostas antigas se o usuário clicar rápido
    detalheReceita.classList.add('is-loading');
    try {
      const dados = await verines.receita(id, porcoes);
      if (seq !== receitaAtual.seq) return;
      receitaAtual.id = id;
      receitaAtual.dados = dados;
      if (montarDoZero) montarDetalhe(dados);
      preencherDetalhe(dados);
    } catch (erro) {
      if (seq !== receitaAtual.seq) return;
      if (montarDoZero) detalheReceita.replaceChildren(blocoErro(erro, () => buscarReceita(id, porcoes, true)));
      else mostrarFeedback($('#porcoes-feedback', detalheReceita), 'erro', erro.message);
    } finally {
      if (seq === receitaAtual.seq) detalheReceita.classList.remove('is-loading');
    }
  }

  /** Monta a estrutura fixa do painel da receita (uma vez por receita). */
  function montarDetalhe(r) {
    const entrada = criar('input', {
      id: 'porcoes-receita', type: 'number', min: '1', max: '50', step: '1', value: r.porcoes, inputmode: 'numeric',
      'aria-describedby': 'porcoes-feedback',
    });
    let espera;
    const aplicar = (valor) => {
      const n = Math.round(Number(valor));
      const fb = $('#porcoes-feedback', detalheReceita);
      if (!Number.isFinite(n) || n < 1 || n > 50) {
        mostrarFeedback(fb, 'erro', 'Escolha entre 1 e 50 porções.');
        return;
      }
      mostrarFeedback(fb, null, '');
      entrada.value = n;
      clearTimeout(espera);
      espera = setTimeout(() => buscarReceita(receitaAtual.id, n, false), 300);
    };
    entrada.addEventListener('input', () => aplicar(entrada.value));

    detalheReceita.replaceChildren(
      criar('span', { class: 'card-kicker', text: r.bloqueada ? 'SEGREDO DO VOVÔ' : 'LIVRO DO VOVÔ' }),
      criar('h3', { text: r.nome }),
      criar('p', { class: 'recipe-desc', text: r.descricao }),
      criar('div', { class: 'servings' },
        criar('label', { for: 'porcoes-receita', text: 'Porções do pedido' }),
        criar('div', { class: 'stepper' },
          criar('button', { type: 'button', 'aria-label': 'Diminuir porções', text: '−', onclick: () => aplicar(Number(entrada.value) - 1) }),
          entrada,
          criar('button', { type: 'button', 'aria-label': 'Aumentar porções', text: '+', onclick: () => aplicar(Number(entrada.value) + 1) }))),
      criar('p', { class: 'feedback', id: 'porcoes-feedback', role: 'status' }),
      criar('div', { class: 'table-scroll' },
        criar('table', { class: 'recipe-table' },
          criar('caption', { class: 'sr-only', text: `Ingredientes de ${r.nome}` }),
          criar('thead', {}, criar('tr', {},
            criar('th', { scope: 'col', text: 'Ingrediente' }),
            criar('th', { scope: 'col', id: 'col-base' }),
            criar('th', { scope: 'col', id: 'col-ajustada' }),
            criar('th', { scope: 'col', text: 'Custo' }))),
          criar('tbody', { id: 'corpo-receita' }))),
      criar('div', { class: 'recovery', id: 'area-recuperacao' }),
      criar('div', { class: 'finance', id: 'financeiro-receita' }),
      criar('div', { class: 'recipe-extra' },
        criar('div', {}, criar('h4', { text: 'Pistas para reconhecer o prato' }),
          criar('ul', { class: 'clue-list' }, r.pistas.map((p) => criar('li', { text: p })))),
        criar('div', {}, criar('h4', { text: 'Modo de preparo' }),
          criar('ol', { class: 'step-list' }, r.passos.map((p) => criar('li', { text: p }))))));
  }

  /** Atualiza só os números (tabela e financeiro) — mantém o foco no campo de porções. */
  function preencherDetalhe(r) {
    const recuperados = lerRecuperados()[r.id] || {};
    $('#col-base', detalheReceita).textContent = `Receita (${r.porcoesBase})`;
    $('#col-ajustada', detalheReceita).textContent = `Para ${r.porcoes}`;

    const linhas = r.ingredientes.map((ing) => {
      const recuperado = recuperados[ing.id];
      let base;
      let ajustada;
      if (!ing.ilegivel) {
        base = `${numeroBR(ing.quantidadeBase)} ${ing.unidade}`;
        ajustada = `${numeroBR(ing.quantidade)} ${ing.unidade}`;
      } else if (recuperado !== undefined) {
        base = criar('span', { class: 'recovered', title: 'Dado recuperado com um desafio' }, `${numeroBR(recuperado)} ${ing.unidade} ✓`);
        ajustada = `${numeroBR((recuperado * r.porcoes) / r.porcoesBase)} ${ing.unidade}`;
      } else {
        base = criar('button', {
          class: 'stain', type: 'button', title: 'Resolver desafio para recuperar este dado',
          onclick: () => abrirRecuperacao(ing.desafio, ing.nome),
        }, '▒▒▒ ', criar('span', { text: 'Recuperar' }));
        ajustada = criar('span', { class: 'muted', text: '?' });
      }
      return criar('tr', { class: ing.ilegivel && recuperado === undefined ? 'is-stained' : null },
        criar('th', { scope: 'row', text: ing.nome }),
        criar('td', {}, base),
        criar('td', {}, ajustada),
        criar('td', { text: ing.custoEstimado === null ? '—' : reais(ing.custoEstimado) }));
    });
    $('#corpo-receita', detalheReceita).replaceChildren(...linhas);

    const f = r.financeiro;
    const caixa = (rotulo, valor, classe) => criar('div', { class: 'finance-box ' + (classe || '') },
      criar('span', { text: rotulo }), criar('strong', { text: valor }));
    $('#financeiro-receita', detalheReceita).replaceChildren(
      caixa('Custo dos ingredientes' + (f.custoCompleto ? '' : '*'), reais(f.custoIngredientes)),
      caixa(`Venda (${r.porcoes} × ${r.precoPorcaoFormatado})`, reais(f.valorVenda)),
      caixa('Lucro estimado', reais(f.lucroEstimado), f.lucroEstimado >= 0 ? 'is-positive' : 'is-negative'),
      f.custoCompleto ? null : criar('p', { class: 'finance-note', text: '* Sem o ingrediente da página manchada (o servidor não revela esse valor).' }));
  }

  /** Desafio para recuperar um dado manchado da receita. */
  async function abrirRecuperacao(idDesafio, nomeIngrediente) {
    const area = $('#area-recuperacao', detalheReceita);
    area.replaceChildren(criar('p', { class: 'loading-text', text: 'Abrindo a página manchada…' }));
    try {
      const d = await verines.desafioRecuperacao(idDesafio);
      const entrada = criar('input', { id: 'resposta-recuperacao', inputmode: 'decimal', autocomplete: 'off', required: true });
      const fb = criar('p', { class: 'feedback', role: 'status' });
      const form = criar('form', { class: 'recovery-box', novalidate: true },
        criar('span', { class: 'card-kicker', text: `PÁGINA MANCHADA · ${d.tema.toUpperCase()}` }),
        criar('p', { class: 'challenge-statement', text: d.enunciado }),
        criar('details', {}, criar('summary', { text: 'Ver dica' }), criar('p', { text: d.dica })),
        criar('label', { class: 'field', for: 'resposta-recuperacao' }, criar('span', { text: `Quantidade de ${nomeIngrediente}` }), entrada),
        criar('div', { class: 'form-actions' },
          criar('button', { class: 'button', type: 'submit', text: 'Recuperar dado' }),
          criar('button', { class: 'button-ghost', type: 'button', text: 'Fechar', onclick: () => area.replaceChildren() })),
        fb);

      form.addEventListener('submit', async (e) => {
        e.preventDefault();
        if (lerNumero(entrada.value) === null) {
          mostrarFeedback(fb, 'erro', 'Digite apenas um número, por exemplo: 120');
          entrada.focus();
          return;
        }
        const botao = $('button[type="submit"]', form);
        botao.disabled = true;
        try {
          const r = await verines.responder(idDesafio, entrada.value);
          if (r.correto) {
            salvarRecuperado(r.recuperado.receita, r.recuperado.ingrediente, r.recuperado.quantidade);
            mostrarFeedback(fb, 'ok', r.mensagem);
            preencherDetalhe(receitaAtual.dados);
            setTimeout(() => form.remove(), 1600);
          } else {
            mostrarFeedback(fb, 'erro', r.mensagem);
            botao.disabled = false;
          }
        } catch (erro) {
          mostrarFeedback(fb, 'erro', erro.message);
          botao.disabled = false;
        }
      });
      area.replaceChildren(form);
      entrada.focus();
    } catch (erro) {
      area.replaceChildren(blocoErro(erro, () => abrirRecuperacao(idDesafio, nomeIngrediente)));
    }
  }

  /* =================================================================
   * 4. Desafios matemáticos e ranking
   * ================================================================= */
  const formDesafio = $('#form-desafio');
  const campoResposta = $('#resposta-desafio');
  const feedbackDesafio = $('#desafio-feedback');
  const dicaDesafio = $('#desafio-dica');
  const btnNovoDesafio = $('#btn-novo-desafio');
  const btnSalvarRanking = $('#btn-salvar-ranking');
  const feedbackRanking = $('#ranking-feedback');
  const listaRanking = $('#lista-ranking');

  const partida = { id: null, pontos: 0, acertos: 0, respondidos: 0, salva: false };
  let desafioAtual = null;
  let ultimoSalvo = null;

  const FORMATOS = {
    numero: { placeholder: 'Ex.: 12,50', modo: 'decimal', valido: (t) => lerNumero(t) !== null, exemplo: 'um número (ex.: 12,50)' },
    fracao: { placeholder: 'Ex.: 3/8', modo: 'text', valido: (t) => /^\s*\d+\s*\/\s*\d+\s*$/.test(t), exemplo: 'uma fração (ex.: 3/8)' },
    lista: { placeholder: 'Ex.: 13; 14', modo: 'text', valido: (t) => t.split(';').length === 2 && t.split(';').every((p) => lerNumero(p) !== null), exemplo: 'dois números separados por ";" (ex.: 13; 14)' },
  };

  function atualizarPlacar() {
    $('#placar-pontos').textContent = partida.pontos;
    $('#placar-acertos').textContent = `${partida.acertos}/${partida.respondidos}`;
    btnSalvarRanking.disabled = partida.respondidos === 0 || partida.salva;
  }

  async function iniciarPartida() {
    const p = await verines.novaPartida();
    Object.assign(partida, { id: p.partidaId, pontos: 0, acertos: 0, respondidos: 0, salva: false });
    atualizarPlacar();
    mostrarFeedback(feedbackRanking, null, '');
  }

  async function novoDesafio() {
    btnNovoDesafio.disabled = true;
    mostrarFeedback(feedbackDesafio, 'info', 'Gerando desafio…');
    try {
      if (!partida.id) await iniciarPartida();
      const tema = $('#tema-desafio').value;
      try {
        desafioAtual = await verines.desafio(tema, partida.id);
      } catch (erro) {
        // Partida expirou (ex.: servidor reiniciado): começa outra e tenta de novo.
        if (erro.codigo !== 'PARTIDA_NAO_ENCONTRADA') throw erro;
        await iniciarPartida();
        desafioAtual = await verines.desafio(tema, partida.id);
      }
      exibirDesafio(desafioAtual);
    } catch (erro) {
      $('#desafio-vazio').hidden = false;
      formDesafio.hidden = true;
      $('#desafio-vazio').replaceChildren(blocoErro(erro, novoDesafio));
    } finally {
      btnNovoDesafio.disabled = false;
    }
  }

  function exibirDesafio(d) {
    const formato = FORMATOS[d.formato] || FORMATOS.numero;
    $('#desafio-vazio').hidden = true;
    formDesafio.hidden = false;
    $('#desafio-tema').textContent = d.tema.toUpperCase();
    $('#desafio-enunciado').textContent = d.enunciado;
    dicaDesafio.textContent = d.dica;
    dicaDesafio.hidden = true;
    $('#btn-dica').textContent = 'Ver dica';
    campoResposta.value = '';
    campoResposta.placeholder = formato.placeholder;
    campoResposta.inputMode = formato.modo;
    campoResposta.disabled = false;
    campoResposta.removeAttribute('aria-invalid');
    $('button[type="submit"]', formDesafio).disabled = false;
    btnNovoDesafio.classList.remove('is-pulsing');
    mostrarFeedback(feedbackDesafio, null, '');
    campoResposta.focus();
  }

  formDesafio.addEventListener('submit', async (e) => {
    e.preventDefault();
    if (!desafioAtual) return;
    const texto = campoResposta.value.trim();
    const formato = FORMATOS[desafioAtual.formato] || FORMATOS.numero;
    // Validação no navegador antes de enviar (o servidor valida de novo).
    if (!texto || !formato.valido(texto)) {
      campoResposta.setAttribute('aria-invalid', 'true');
      mostrarFeedback(feedbackDesafio, 'erro', `Responda com ${formato.exemplo}.`);
      campoResposta.focus();
      return;
    }
    campoResposta.removeAttribute('aria-invalid');
    const botao = $('button[type="submit"]', formDesafio);
    botao.disabled = true;
    try {
      const r = await verines.responder(desafioAtual.id, texto);
      campoResposta.disabled = true;
      if (r.placar) Object.assign(partida, r.placar);
      atualizarPlacar();
      mostrarFeedback(feedbackDesafio, r.correto ? 'ok' : 'erro',
        r.correto ? `✓ ${r.mensagem} +${r.pontosGanhos} pontos. (${r.explicacao})` : `✗ ${r.mensagem} Resposta: ${r.explicacao}`);
      btnNovoDesafio.classList.add('is-pulsing');
      btnNovoDesafio.focus();
    } catch (erro) {
      mostrarFeedback(feedbackDesafio, 'erro', erro.message);
      if (erro.codigo === 'FORMATO_INVALIDO' || erro.tipo !== 'http') botao.disabled = false;
    }
  });

  $('#btn-dica').addEventListener('click', (e) => {
    dicaDesafio.hidden = !dicaDesafio.hidden;
    e.currentTarget.textContent = dicaDesafio.hidden ? 'Ver dica' : 'Esconder dica';
  });
  btnNovoDesafio.addEventListener('click', novoDesafio);
  $('#btn-nova-partida').addEventListener('click', async () => {
    try {
      await iniciarPartida();
      await novoDesafio();
    } catch (erro) {
      mostrarFeedback(feedbackDesafio, 'erro', erro.message);
    }
  });

  async function carregarRanking() {
    try {
      const { ranking } = await verines.ranking(10);
      if (!ranking.length) {
        listaRanking.replaceChildren(criar('li', { class: 'ranking-empty', text: 'Ninguém no ranking ainda. Seja o primeiro!' }));
        return;
      }
      listaRanking.replaceChildren(...ranking.map((item, i) => criar('li', { class: item.id === ultimoSalvo ? 'is-new' : null },
        criar('span', { class: 'ranking-pos', text: i < 3 ? ['🥇', '🥈', '🥉'][i] : `${i + 1}º` }),
        criar('span', { class: 'ranking-name', text: item.nome }),
        criar('span', { class: 'ranking-score' }, criar('b', { text: item.pontos }), ` pts · ${item.acertos}/${item.respondidos}`))));
    } catch (erro) {
      listaRanking.replaceChildren(criar('li', {}, blocoErro(erro, carregarRanking)));
    }
  }

  $('#form-ranking').addEventListener('submit', async (e) => {
    e.preventDefault();
    const campo = $('#nome-ranking');
    const nome = campo.value.trim();
    if (nome.length < 2 || nome.length > 20) {
      campo.setAttribute('aria-invalid', 'true');
      mostrarFeedback(feedbackRanking, 'erro', 'O nome precisa ter entre 2 e 20 caracteres.');
      campo.focus();
      return;
    }
    campo.removeAttribute('aria-invalid');
    btnSalvarRanking.disabled = true;
    try {
      const salvo = await verines.salvarRanking(partida.id, nome);
      partida.salva = true;
      ultimoSalvo = salvo.id;
      mostrarFeedback(feedbackRanking, 'ok', `Pontuação salva: ${salvo.pontos} pontos! Recomece a partida para jogar de novo.`);
      await carregarRanking();
    } catch (erro) {
      mostrarFeedback(feedbackRanking, 'erro', erro.message);
    } finally {
      atualizarPlacar();
    }
  });

  /* =================================================================
   * 5. Mercado do dia — AwesomeAPI (cotação real do dólar e do euro)
   * ================================================================= */
  const PRODUTOS_IMPORTADOS = [
    { nome: 'fava de baunilha de Madagascar', moeda: 'USD', preco: 8.5, unidade: 'fava' },
    { nome: 'queijo Parmigiano Reggiano', moeda: 'EUR', preco: 24.9, unidade: 'kg' },
    { nome: 'chocolate belga 70%', moeda: 'EUR', preco: 12.4, unidade: 'kg' },
    { nome: 'xarope de bordo canadense', moeda: 'USD', preco: 11.75, unidade: 'frasco' },
    { nome: 'açafrão espanhol', moeda: 'EUR', preco: 6.3, unidade: 'grama' },
    { nome: 'canela do Sri Lanka', moeda: 'USD', preco: 5.2, unidade: 'pacote de 100 g' },
  ];
  const caixaCotacoes = $('#cotacoes');
  const formMercado = $('#form-mercado');
  const campoMercado = $('#resposta-mercado');
  const feedbackMercado = $('#mercado-feedback');
  const btnNovoProduto = $('#btn-novo-produto');
  let cotacaoAtual = null;
  let perguntaMercado = null;

  function habilitarMercado(ativo) {
    campoMercado.disabled = !ativo;
    btnNovoProduto.disabled = !ativo;
    $('button[type="submit"]', formMercado).disabled = !ativo;
  }

  async function carregarCotacoes() {
    const botao = $('#btn-atualizar-cotacao');
    botao.disabled = true;
    caixaCotacoes.replaceChildren(criar('p', { class: 'loading-text', text: 'Buscando cotações…' }));
    try {
      cotacaoAtual = await externas.cotacoes();
      caixaCotacoes.replaceChildren(...['USD', 'EUR'].map((codigo) => {
        const c = cotacaoAtual[codigo];
        const sobe = c.variacao >= 0;
        return criar('div', { class: 'rate' },
          criar('span', { class: 'rate-label', text: `1 ${c.codigo} (${c.simbolo})` }),
          criar('strong', { class: 'rate-value', text: `R$ ${dinheiroBR(c.valor)}` }),
          criar('span', { class: 'rate-change ' + (sobe ? 'is-up' : 'is-down'), text: `${sobe ? '▲' : '▼'} ${numeroBR(Math.abs(c.variacao))}% hoje` }));
      }));
      const quando = cotacaoAtual.USD.atualizadoEm
        ? new Date(cotacaoAtual.USD.atualizadoEm.replace(' ', 'T')).toLocaleString('pt-BR', { dateStyle: 'short', timeStyle: 'short' })
        : 'agora';
      $('#cotacao-fonte').textContent = `Fonte: AwesomeAPI (economia.awesomeapi.com.br) · cotação de ${quando}`;
      habilitarMercado(true);
      novaPerguntaMercado();
    } catch (erro) {
      cotacaoAtual = null;
      habilitarMercado(false);
      $('#cotacao-fonte').textContent = '';
      $('#mercado-enunciado').textContent = 'O desafio precisa da cotação do dia. Tente atualizar em instantes.';
      caixaCotacoes.replaceChildren(blocoErro(erro, carregarCotacoes, { externa: true }));
    } finally {
      botao.disabled = false;
    }
  }

  function novaPerguntaMercado() {
    if (!cotacaoAtual) return;
    const p = PRODUTOS_IMPORTADOS[Math.floor(Math.random() * PRODUTOS_IMPORTADOS.length)];
    const cot = cotacaoAtual[p.moeda];
    const valorReal = Math.round(cot.valor * 100) / 100; // a conta usa a cotação com 2 casas, como aparece na tela
    const precoTexto = `${cot.simbolo} ${dinheiroBR(p.preco)}`;

    if (Math.random() < 0.5) {
      const qtd = 1 + Math.floor(Math.random() * 4);
      const resposta = Math.round(qtd * p.preco * valorReal * 100) / 100;
      perguntaMercado = {
        resposta, tolerancia: 0.05,
        explicacao: `${qtd} × ${precoTexto} = ${cot.simbolo} ${dinheiroBR(qtd * p.preco)}; × R$ ${dinheiroBR(valorReal)} = R$ ${dinheiroBR(resposta)}`,
      };
      $('#mercado-enunciado').textContent = `O Verine's vai comprar ${qtd} × ${p.nome} (${precoTexto} por ${p.unidade}). ` +
        `Com a cotação de hoje (R$ ${dinheiroBR(valorReal)}), quanto custará a compra em reais? (arredonde para centavos)`;
    } else {
      const orcamento = [150, 200, 300, 500][Math.floor(Math.random() * 4)];
      const unitarioReais = p.preco * valorReal;
      const resposta = Math.floor(orcamento / unitarioReais);
      perguntaMercado = {
        resposta, tolerancia: 0,
        explicacao: `${precoTexto} × R$ ${dinheiroBR(valorReal)} = R$ ${dinheiroBR(unitarioReais)} por ${p.unidade}; ` +
          `R$ ${orcamento} ÷ ${dinheiroBR(unitarioReais)} ≈ ${numeroBR(orcamento / unitarioReais)} → ${resposta}`,
      };
      $('#mercado-enunciado').textContent = `Com um orçamento de R$ ${dinheiroBR(orcamento)}, quantas unidades de ${p.nome} (${precoTexto} por ${p.unidade}) ` +
        `o Verine's consegue comprar? Use a cotação de hoje (R$ ${dinheiroBR(valorReal)}).`;
    }
    campoMercado.value = '';
    campoMercado.disabled = false;
    $('button[type="submit"]', formMercado).disabled = false;
    mostrarFeedback(feedbackMercado, null, '');
  }

  formMercado.addEventListener('submit', (e) => {
    e.preventDefault();
    if (!perguntaMercado) return;
    const n = lerNumero(campoMercado.value);
    if (n === null) {
      campoMercado.setAttribute('aria-invalid', 'true');
      mostrarFeedback(feedbackMercado, 'erro', 'Digite um número, por exemplo: 45,90');
      campoMercado.focus();
      return;
    }
    campoMercado.removeAttribute('aria-invalid');
    const certo = Math.abs(n - perguntaMercado.resposta) <= perguntaMercado.tolerancia + 1e-9;
    mostrarFeedback(feedbackMercado, certo ? 'ok' : 'erro', `${certo ? '✓ Conta certa!' : '✗ Ainda não.'} ${perguntaMercado.explicacao}`);
    campoMercado.disabled = true;
    $('button[type="submit"]', formMercado).disabled = true;
  });
  btnNovoProduto.addEventListener('click', novaPerguntaMercado);
  $('#btn-atualizar-cotacao').addEventListener('click', carregarCotacoes);

  /* =================================================================
   * 6. Contato — ViaCEP + POST /api/mensagens
   * ================================================================= */
  const formContato = $('#form-contato');
  const campoCep = $('#contato-cep');
  const feedbackContato = $('#contato-feedback');
  let ultimoCepBuscado = '';

  const erroCampo = (nome) => $(`[data-erro="${nome}"]`, formContato);
  function marcarErro(nome, mensagem) {
    const campo = formContato.elements[nome];
    const aviso = erroCampo(nome);
    if (aviso) {
      aviso.textContent = mensagem || '';
      aviso.classList.remove('is-info');
    }
    if (campo) campo.toggleAttribute('aria-invalid', Boolean(mensagem));
  }

  // Máscara 00000-000 e busca automática quando o CEP fica completo
  campoCep.addEventListener('input', () => {
    const digitos = campoCep.value.replace(/\D/g, '').slice(0, 8);
    campoCep.value = digitos.length > 5 ? `${digitos.slice(0, 5)}-${digitos.slice(5)}` : digitos;
    marcarErro('cep', '');
    if (digitos.length === 8 && digitos !== ultimoCepBuscado) buscarCep(digitos);
  });

  async function buscarCep(cep) {
    ultimoCepBuscado = cep;
    const aviso = erroCampo('cep');
    aviso.textContent = 'Buscando endereço…';
    aviso.classList.add('is-info');
    try {
      const end = await externas.buscarCep(cep);
      if (campoCep.value.replace(/\D/g, '') !== cep) return; // usuário já mudou o CEP
      formContato.elements.cidade.value = end.cidade;
      formContato.elements.uf.value = end.uf;
      aviso.textContent = `📍 ${end.bairro ? end.bairro + ', ' : ''}${end.cidade}/${end.uf}`;
    } catch (erro) {
      ultimoCepBuscado = '';
      aviso.classList.remove('is-info');
      aviso.textContent = erro.tipo === 'http' || erro.tipo === 'formato'
        ? erro.message
        : 'Não foi possível consultar o CEP agora. Preencha a cidade manualmente.';
    }
  }

  const textoMensagem = formContato.elements.mensagem;
  textoMensagem.addEventListener('input', () => {
    $('#contador-mensagem').textContent = textoMensagem.value.length;
  });

  function validarContato(d) {
    const erros = {};
    if (d.nome.length < 2) erros.nome = 'Informe seu nome.';
    if (!/^[^\s@]+@[^\s@]+\.[^\s@]{2,}$/.test(d.email)) erros.email = 'Informe um e-mail válido.';
    if (!d.perfil) erros.perfil = 'Escolha uma opção.';
    if (d.cep && d.cep.length !== 8) erros.cep = 'O CEP deve ter 8 dígitos.';
    if (d.uf && !/^[A-Za-z]{2}$/.test(d.uf)) erros.uf = 'Use a sigla (ex.: SP).';
    if (d.mensagem.length < 10) erros.mensagem = 'Escreva pelo menos 10 caracteres.';
    return erros;
  }

  formContato.addEventListener('submit', async (e) => {
    e.preventDefault();
    const el = formContato.elements;
    const dados = {
      nome: el.nome.value.trim(),
      email: el.email.value.trim(),
      perfil: el.perfil.value,
      cep: el.cep.value.replace(/\D/g, ''),
      cidade: el.cidade.value.trim(),
      uf: el.uf.value.trim().toUpperCase(),
      mensagem: el.mensagem.value.trim(),
    };
    ['nome', 'email', 'perfil', 'cep', 'uf', 'mensagem'].forEach((c) => marcarErro(c, ''));
    const erros = validarContato(dados);
    if (Object.keys(erros).length) {
      Object.entries(erros).forEach(([c, m]) => marcarErro(c, m));
      mostrarFeedback(feedbackContato, 'erro', 'Confira os campos destacados.');
      el[Object.keys(erros)[0]].focus();
      return;
    }

    const botao = $('#btn-enviar-contato');
    botao.disabled = true;
    botao.textContent = 'Enviando…';
    mostrarFeedback(feedbackContato, 'info', 'Enviando sua mensagem…');
    try {
      const r = await verines.enviarMensagem(dados);
      formContato.reset();
      ultimoCepBuscado = '';
      $('#contador-mensagem').textContent = '0';
      erroCampo('cep').textContent = '';
      mostrarFeedback(feedbackContato, 'ok',
        `Mensagem recebida! Protocolo #${r.id.slice(0, 8).toUpperCase()} — ${new Date(r.recebidaEm).toLocaleString('pt-BR')}.`);
      carregarEstatisticas();
    } catch (erro) {
      if (erro.campos) Object.entries(erro.campos).forEach(([c, m]) => marcarErro(c, m));
      mostrarFeedback(feedbackContato, 'erro', erro.message);
    } finally {
      botao.disabled = false;
      botao.textContent = 'Enviar mensagem';
    }
  });

  async function carregarEstatisticas() {
    const lista = $('#estatisticas-contato');
    try {
      const s = await verines.estatisticasMensagens();
      const perfilTop = Object.entries(s.porPerfil).sort((a, b) => b[1] - a[1])[0];
      lista.replaceChildren(
        criar('li', {}, criar('b', { text: s.total }), s.total === 1 ? ' mensagem recebida' : ' mensagens recebidas'),
        criar('li', {}, criar('b', { text: s.cidadesDiferentes }), s.cidadesDiferentes === 1 ? ' cidade' : ' cidades diferentes'),
        s.total ? criar('li', {}, 'Mais participativos: ', criar('b', { text: perfilTop[0] })) : null);
    } catch {
      lista.replaceChildren(); // sem servidor, a lista simplesmente não aparece
    }
  }

  /* =================================================================
   * 7. Informações do download (tamanho e data vindos da API)
   * ================================================================= */
  async function carregarInfoJogo() {
    try {
      const info = await verines.jogo();
      if (!info.disponivel) return;
      const mb = (info.tamanhoBytes / (1024 * 1024)).toLocaleString('pt-BR', { maximumFractionDigits: 1 });
      $('#download-status').textContent = `Download disponível · ${mb} MB`;
      $('#download-note').textContent = `Arquivo ${info.arquivo}, atualizado em ${new Date(info.atualizadoEm).toLocaleDateString('pt-BR')}. ${info.plataforma}.`;
      $('#download-version').textContent = `JOGO PARA PC · ${mb} MB`;
    } catch {
      /* sem servidor: mantém o texto padrão definido em script.js */
    }
  }

  /* =================================================================
   * 8. Monitor de APIs (deixa visível como os dados chegam)
   * ================================================================= */
  const btnMonitor = $('#btn-monitor');
  const painelMonitor = $('#monitor-api');
  const listaMonitor = $('#monitor-lista');
  let totalRequisicoes = 0;
  let vistas = new WeakSet();

  function abrirMonitor(abrir) {
    painelMonitor.hidden = !abrir;
    btnMonitor.setAttribute('aria-expanded', String(abrir));
    if (abrir) $('#btn-fechar-monitor').focus();
  }
  btnMonitor.addEventListener('click', () => abrirMonitor(painelMonitor.hidden));

  // O botão flutuante só aparece depois do topo da página, para não cobrir o selo do hero.
  new IntersectionObserver(([item]) => {
    btnMonitor.classList.toggle('is-hidden', item.isIntersecting && painelMonitor.hidden);
  }, { threshold: 0.35 }).observe($('.hero'));
  $('#btn-fechar-monitor').addEventListener('click', () => { abrirMonitor(false); btnMonitor.focus(); });
  document.addEventListener('keydown', (e) => { if (e.key === 'Escape' && !painelMonitor.hidden) abrirMonitor(false); });

  const resumirJson = (obj) => {
    const texto = JSON.stringify(obj, null, 2);
    return texto.length > 1600 ? texto.slice(0, 1600) + '\n…' : texto;
  };

  monitor.assinar((entradas) => {
    entradas.forEach((e) => { if (!vistas.has(e)) { vistas.add(e); totalRequisicoes += 1; } });
    $('#monitor-contador').textContent = totalRequisicoes;
    if (!entradas.length) {
      listaMonitor.replaceChildren(criar('li', { class: 'monitor-empty', text: 'Nenhuma requisição ainda.' }));
      return;
    }
    listaMonitor.replaceChildren(...entradas.map((e) => {
      const ok = typeof e.status === 'number' && e.status < 400;
      const pendente = e.status === '…';
      return criar('li', { class: 'monitor-item' },
        criar('div', { class: 'monitor-line' },
          criar('span', { class: 'method method-' + e.metodo.toLowerCase(), text: e.metodo }),
          criar('span', { class: 'monitor-source', text: e.fonte }),
          criar('span', { class: 'monitor-status ' + (pendente ? 'is-pending' : ok ? 'is-ok' : 'is-fail'), text: String(e.status) }),
          criar('span', { class: 'monitor-time', text: e.ms === null ? '' : `${e.ms} ms` })),
        criar('code', { class: 'monitor-url', text: e.url.replace(location.origin, '') }),
        e.corpoEnviado && Object.keys(e.corpoEnviado).length
          ? criar('details', {}, criar('summary', { text: 'Dados enviados (JSON)' }), criar('pre', { text: resumirJson(e.corpoEnviado) }))
          : null,
        e.resposta !== null
          ? criar('details', {}, criar('summary', { text: 'Resposta recebida (JSON)' }), criar('pre', { text: resumirJson(e.resposta) }))
          : null,
        e.erro ? criar('p', { class: 'monitor-error', text: e.erro }) : null);
    }));
  });

  /* =================================================================
   * Inicialização
   * ================================================================= */
  (async function iniciar() {
    await verificarServidor();
    ativarAba(abas[0]);
    carregarInfoJogo();
    carregarEstatisticas();
    $('[data-api-status]').addEventListener('click', verificarServidor);
  })();
})();
