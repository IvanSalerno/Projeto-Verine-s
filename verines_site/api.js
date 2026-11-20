/**
 * api.js — Camada de comunicação HTTP do site Verine's.
 *
 * Todas as requisições do site passam pela função `requisitar`, que:
 *   - usa a Fetch API (GET e POST com JSON);
 *   - cancela a requisição se demorar demais (AbortController + timeout);
 *   - transforma qualquer falha (rede, timeout, HTTP 4xx/5xx, JSON inválido)
 *     em um ErroApi com uma mensagem amigável em português;
 *   - registra cada chamada no "Monitor de APIs" (painel visível no site).
 *
 * APIs usadas:
 *   1) API do Verine's (própria) — server/server.js
 *   2) AwesomeAPI de cotações   — https://economia.awesomeapi.com.br (gratuita, sem chave)
 *   3) ViaCEP                   — https://viacep.com.br (gratuita, sem chave)
 */
(function () {
  'use strict';

  /* Endereço da API própria:
   * - se o site foi aberto pelo próprio servidor (porta 3000), usa o mesmo endereço;
   * - caso contrário (arquivo aberto direto, Live Server etc.), tenta http://localhost:3000;
   * - pode ser trocado pela tag <meta name="verines-api" content="https://...">. */
  const meta = document.querySelector('meta[name="verines-api"]');
  const BASE_PROPRIA = (meta && meta.content.trim()) || (location.port === '3000' ? '' : 'http://localhost:3000');

  const URL_COTACAO = 'https://economia.awesomeapi.com.br/json/last/USD-BRL,EUR-BRL';
  const URL_VIACEP = 'https://viacep.com.br/ws/';

  /** Erro padronizado de API. `tipo`: 'rede' | 'timeout' | 'http' | 'formato'. */
  class ErroApi extends Error {
    constructor(mensagem, { tipo, status = 0, codigo = null, campos = null } = {}) {
      super(mensagem);
      this.name = 'ErroApi';
      this.tipo = tipo;
      this.status = status;
      this.codigo = codigo;
      this.campos = campos;
    }
  }

  /* ------------------------------------------------------------------
   * Monitor de requisições (alimenta o painel "Monitor de APIs")
   * ------------------------------------------------------------------ */
  const entradas = [];
  const ouvintes = new Set();
  const avisar = () => ouvintes.forEach((fn) => fn(entradas));

  function registrar(entrada) {
    entradas.unshift(entrada);
    if (entradas.length > 25) entradas.pop();
    avisar();
    return entrada;
  }

  /* ------------------------------------------------------------------
   * Função central de requisição
   * ------------------------------------------------------------------ */
  async function requisitar(url, { metodo = 'GET', corpo, timeout = 8000, fonte = "API do Verine's" } = {}) {
    const controle = new AbortController();
    const temporizador = setTimeout(() => controle.abort(), timeout);
    const entrada = registrar({ fonte, metodo, url, status: '…', ms: null, corpoEnviado: corpo ?? null, resposta: null, erro: null });
    const inicio = performance.now();

    const opcoes = { method: metodo, signal: controle.signal, headers: { Accept: 'application/json' } };
    if (corpo !== undefined) {
      opcoes.headers['Content-Type'] = 'application/json';
      opcoes.body = JSON.stringify(corpo);
    }

    try {
      let resposta;
      try {
        resposta = await fetch(url, opcoes);
      } catch (falha) {
        if (falha.name === 'AbortError') {
          throw new ErroApi('O servidor demorou demais para responder. Tente novamente.', { tipo: 'timeout' });
        }
        throw new ErroApi('Não foi possível conectar ao serviço. Verifique sua internet ou se o servidor está ligado.', { tipo: 'rede' });
      }

      entrada.status = resposta.status;
      let dados = null;
      const texto = await resposta.text();
      if (texto) {
        try {
          dados = JSON.parse(texto);
        } catch {
          throw new ErroApi('O serviço respondeu em um formato inesperado.', { tipo: 'formato', status: resposta.status });
        }
      }
      entrada.resposta = dados;

      if (!resposta.ok) {
        const info = (dados && dados.erro) || {};
        throw new ErroApi(info.mensagem || `O serviço respondeu com erro ${resposta.status}.`, {
          tipo: 'http', status: resposta.status, codigo: info.codigo || null, campos: info.campos || null,
        });
      }
      return dados;
    } catch (erro) {
      entrada.erro = erro.message;
      if (entrada.status === '…') entrada.status = erro.tipo === 'timeout' ? 'tempo esgotado' : 'falhou';
      throw erro;
    } finally {
      clearTimeout(temporizador);
      entrada.ms = Math.round(performance.now() - inicio);
      avisar();
    }
  }

  const propria = (caminho, opcoes) => requisitar(BASE_PROPRIA + caminho, opcoes);
  const post = (corpo) => ({ metodo: 'POST', corpo });

  /* ------------------------------------------------------------------
   * API do Verine's (própria)
   * ------------------------------------------------------------------ */
  const verines = {
    status: () => propria('/api/status', { timeout: 4000 }),
    receitas: () => propria('/api/receitas'),
    receita: (id, porcoes) => propria(`/api/receitas/${encodeURIComponent(id)}` + (porcoes ? `?porcoes=${encodeURIComponent(porcoes)}` : '')),
    novaPartida: () => propria('/api/partidas', post({})),
    desafio: (tema, partidaId) => {
      const params = new URLSearchParams({ tema });
      if (partidaId) params.set('partida', partidaId);
      return propria(`/api/desafios?${params}`);
    },
    desafioRecuperacao: (id) => propria(`/api/desafios/${encodeURIComponent(id)}`),
    responder: (id, resposta) => propria(`/api/desafios/${encodeURIComponent(id)}/resposta`, post({ resposta })),
    ranking: (limite = 10) => propria(`/api/ranking?limite=${limite}`),
    salvarRanking: (partidaId, nome) => propria('/api/ranking', post({ partidaId, nome })),
    enviarMensagem: (dados) => propria('/api/mensagens', post(dados)),
    estatisticasMensagens: () => propria('/api/mensagens/estatisticas'),
    jogo: () => propria('/api/jogo'),
  };

  /* ------------------------------------------------------------------
   * APIs externas
   * ------------------------------------------------------------------ */
  const numero = (valor) => {
    const n = Number(valor);
    return Number.isFinite(n) && n > 0 ? n : null;
  };

  /** Cotação do dólar e do euro (AwesomeAPI). Valida e devolve só o que o site usa. */
  async function cotacoes() {
    const dados = await requisitar(URL_COTACAO, { fonte: 'AwesomeAPI', timeout: 8000 });
    const montar = (chave, simbolo) => {
      const item = dados && dados[chave];
      const bid = item && numero(item.bid);
      if (!bid) throw new ErroApi('A cotação recebida está incompleta.', { tipo: 'formato' });
      return {
        codigo: item.code,
        simbolo,
        nome: item.name,
        valor: bid,
        variacao: Number(item.pctChange) || 0,
        atualizadoEm: item.create_date || null,
      };
    };
    return { USD: montar('USDBRL', 'US$'), EUR: montar('EURBRL', '€') };
  }

  /** Endereço a partir do CEP (ViaCEP). */
  async function buscarCep(cep) {
    const limpo = String(cep).replace(/\D/g, '');
    if (limpo.length !== 8) throw new ErroApi('O CEP precisa ter 8 dígitos.', { tipo: 'formato' });
    const dados = await requisitar(`${URL_VIACEP}${limpo}/json/`, { fonte: 'ViaCEP', timeout: 6000 });
    // A ViaCEP responde 200 com { "erro": true } (ou "true") quando o CEP não existe.
    if (!dados || dados.erro === true || dados.erro === 'true') {
      throw new ErroApi('CEP não encontrado. Confira os números.', { tipo: 'http', status: 404 });
    }
    return { cep: dados.cep, cidade: dados.localidade, uf: dados.uf, bairro: dados.bairro, rua: dados.logradouro };
  }

  window.VerinesAPI = {
    base: BASE_PROPRIA || location.origin,
    ErroApi,
    verines,
    externas: { cotacoes, buscarCep },
    monitor: {
      entradas: () => entradas,
      assinar: (fn) => { ouvintes.add(fn); fn(entradas); return () => ouvintes.delete(fn); },
    },
  };
})();
