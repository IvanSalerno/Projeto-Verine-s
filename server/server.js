/**
 * API do Verine's — servidor HTTP próprio do projeto.
 *
 * Feito apenas com módulos nativos do Node.js (http, fs, path, crypto),
 * sem frameworks nem dependências externas. Ele tem duas funções:
 *   1) expor uma API REST em /api/... (JSON) usada pelo site;
 *   2) servir os arquivos do site (index.html, CSS, JS, imagens).
 *
 * Como rodar (na pasta do projeto):   node server/server.js
 * Depois abra:                          http://localhost:3000
 *
 * Endpoints (resumo — veja o README para exemplos):
 *   GET  /api/status                       saúde da API e lista de rotas
 *   GET  /api/receitas                     resumo do livro de receitas
 *   GET  /api/receitas/:id?porcoes=N       receita com quantidades ajustadas
 *   POST /api/partidas                     inicia uma partida de desafios
 *   GET  /api/desafios?tema=X&partida=ID   gera um desafio matemático
 *   GET  /api/desafios/:id                 enunciado de um desafio de recuperação
 *   POST /api/desafios/:id/resposta        corrige a resposta enviada
 *   GET  /api/ranking?limite=10            melhores pontuações
 *   POST /api/ranking                      salva a pontuação de uma partida
 *   POST /api/mensagens                    recebe mensagem do formulário de contato
 *   GET  /api/mensagens/estatisticas       totais de mensagens por perfil
 *   GET  /api/jogo                         informações do arquivo do jogo
 */

'use strict';

const http = require('http');
const fs = require('fs');
const fsp = require('fs/promises');
const path = require('path');
const crypto = require('crypto');

const PORT = Number(process.env.PORT) || 3000;
const RAIZ_SITE = path.resolve(__dirname, '..');
const PASTA_DADOS = path.join(__dirname, 'data');
const ARQ_RANKING = path.join(PASTA_DADOS, 'ranking.json');
const ARQ_MENSAGENS = path.join(PASTA_DADOS, 'mensagens.json');
const ARQ_JOGO = path.join(RAIZ_SITE, 'verines_site', "Verine'sGame.zip");
const LIMITE_CORPO = 10 * 1024; // 10 KB por requisição POST
const VALIDADE_DESAFIO_MS = 30 * 60 * 1000; // um desafio vale por 30 minutos
const PONTOS_POR_ACERTO = 10;

const catalogo = JSON.parse(fs.readFileSync(path.join(PASTA_DADOS, 'catalogo.json'), 'utf8'));

/* =====================================================================
 * Estado em memória (desafios gerados e partidas em andamento).
 * A resposta correta fica SÓ no servidor: o navegador recebe apenas
 * o enunciado, então não dá para "colar" olhando o código da página.
 * ===================================================================== */
const desafios = new Map(); // id -> { resposta, formato, tolerancia, partidaId, respondido, expira, ... }
const partidas = new Map(); // id -> { pontos, acertos, respondidos, salva, criadaEm }

setInterval(() => {
  const agora = Date.now();
  for (const [id, d] of desafios) if (d.expira < agora) desafios.delete(id);
  for (const [id, p] of partidas) if (p.criadaEm + 6 * VALIDADE_DESAFIO_MS < agora) partidas.delete(id);
}, 10 * 60 * 1000).unref();

/* =====================================================================
 * Utilitários
 * ===================================================================== */
class ErroApi extends Error {
  constructor(status, codigo, mensagem) {
    super(mensagem);
    this.status = status;
    this.codigo = codigo;
  }
}

const novoId = () => crypto.randomUUID();
const sortear = (lista) => lista[Math.floor(Math.random() * lista.length)];
const inteiroEntre = (min, max) => min + Math.floor(Math.random() * (max - min + 1));
const reais = (centavos) => 'R$ ' + (centavos / 100).toFixed(2).replace('.', ',');
const fmtNumero = (n) => (Number.isInteger(n) ? String(n) : n.toFixed(2).replace('.', ','));

function enviarJson(res, status, corpo) {
  const texto = JSON.stringify(corpo);
  res.writeHead(status, {
    'Content-Type': 'application/json; charset=utf-8',
    'Content-Length': Buffer.byteLength(texto),
    'Cache-Control': 'no-store',
  });
  res.end(texto);
}

function aplicarCors(res) {
  // Permite que o site seja aberto por outra origem (ex.: Live Server na porta 5500).
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');
}

/** Lê e interpreta o corpo JSON de um POST, com limite de tamanho. */
function lerCorpoJson(req) {
  return new Promise((resolve, reject) => {
    const tipo = req.headers['content-type'] || '';
    if (!tipo.includes('application/json')) {
      reject(new ErroApi(415, 'TIPO_INVALIDO', 'Envie os dados em JSON (Content-Type: application/json).'));
      return;
    }
    let tamanho = 0;
    const partes = [];
    req.on('data', (parte) => {
      tamanho += parte.length;
      if (tamanho > LIMITE_CORPO) {
        reject(new ErroApi(413, 'CORPO_GRANDE', 'Os dados enviados são grandes demais.'));
        req.destroy();
        return;
      }
      partes.push(parte);
    });
    req.on('end', () => {
      try {
        const dados = JSON.parse(Buffer.concat(partes).toString('utf8') || '{}');
        if (typeof dados !== 'object' || dados === null || Array.isArray(dados)) throw new Error();
        resolve(dados);
      } catch {
        reject(new ErroApi(400, 'JSON_INVALIDO', 'O corpo da requisição não é um JSON válido.'));
      }
    });
    req.on('error', reject);
  });
}

/** Leitura/gravação de arquivos JSON usados como "banco de dados" simples. */
async function lerLista(arquivo) {
  try {
    const dados = JSON.parse(await fsp.readFile(arquivo, 'utf8'));
    return Array.isArray(dados) ? dados : [];
  } catch (erro) {
    if (erro.code === 'ENOENT') return [];
    throw erro;
  }
}

let filaGravacao = Promise.resolve();
function gravarLista(arquivo, lista) {
  // Grava em arquivo temporário e renomeia: evita arquivo corrompido se o servidor cair no meio.
  // A fila garante que duas gravações nunca aconteçam ao mesmo tempo.
  filaGravacao = filaGravacao.then(async () => {
    const temp = arquivo + '.tmp';
    await fsp.writeFile(temp, JSON.stringify(lista, null, 2), 'utf8');
    await fsp.rename(temp, arquivo);
  });
  return filaGravacao;
}

const limparTexto = (valor, max) =>
  String(valor ?? '')
    .replace(/[<>]/g, '') // evita HTML injetado
    .replace(/\s+/g, ' ')
    .trim()
    .slice(0, max);

/* =====================================================================
 * Receitas
 * ===================================================================== */
function resumoReceita(r) {
  return {
    id: r.id,
    nome: r.nome,
    descricao: r.descricao,
    porcoesBase: r.porcoesBase,
    precoPorcao: r.precoPorcao,
    precoPorcaoFormatado: reais(r.precoPorcao),
    bloqueada: r.bloqueada,
    totalIngredientes: r.ingredientes.length,
    temPaginaManchada: r.ingredientes.some((i) => i.ilegivel),
  };
}

function receitaAjustada(r, porcoes) {
  const fator = porcoes / r.porcoesBase;
  let custoCentavos = 0;
  let custoCompleto = true;

  const ingredientes = r.ingredientes.map((linha) => {
    const ing = catalogo.ingredientes[linha.id];
    const ajustada = Math.round(linha.quantidade * fator * 100) / 100;
    // custo proporcional: (quantidade usada / tamanho do pacote) × preço do pacote
    const custo = Math.round((ajustada / ing.pacote) * ing.precoPacote);
    if (linha.ilegivel) custoCompleto = false;
    else custoCentavos += custo;

    return {
      id: linha.id,
      nome: ing.nome,
      unidade: ing.unidade,
      categoria: ing.categoria,
      // Dado manchado: o valor real NÃO é enviado — precisa ser recuperado com um desafio.
      ilegivel: Boolean(linha.ilegivel),
      quantidadeBase: linha.ilegivel ? null : linha.quantidade,
      quantidade: linha.ilegivel ? null : ajustada,
      custoEstimado: linha.ilegivel ? null : custo,
      desafio: linha.ilegivel ? linha.desafio : null,
    };
  });

  const receitaCliente = porcoes * r.precoPorcao;
  return {
    ...resumoReceita(r),
    porcoes,
    fator: Math.round(fator * 1000) / 1000,
    pistas: r.pistas,
    passos: r.passos,
    ingredientes,
    financeiro: {
      custoIngredientes: custoCentavos,
      custoCompleto, // false quando falta algum dado manchado no cálculo
      valorVenda: receitaCliente,
      lucroEstimado: receitaCliente - custoCentavos,
    },
  };
}

/* =====================================================================
 * Geradores de desafios matemáticos — baseados no ChallengeFactory do jogo
 * e sempre usando dados reais do catálogo.
 * ===================================================================== */
const geradores = {
  proporcao() {
    const r = sortear(catalogo.receitas.filter((x) => !x.bloqueada));
    const linha = sortear(r.ingredientes.filter((l) => !l.ilegivel));
    const ing = catalogo.ingredientes[linha.id];
    const opcoes = [1, 2, 3, 5, 6, 8, 10].filter((p) => p !== r.porcoesBase);
    const porcoes = sortear(opcoes);
    const resposta = (linha.quantidade * porcoes) / r.porcoesBase;
    return {
      tema: 'Razão e proporção',
      formato: 'numero',
      unidade: ing.unidade,
      tolerancia: 0.01,
      resposta,
      enunciado: `A receita "${r.nome}" usa ${linha.quantidade} ${ing.unidade} de ${ing.nome} para ${r.porcoesBase} porções. ` +
        `Quanto de ${ing.nome} é necessário para ${porcoes} porções? (responda em ${ing.unidade})`,
      dica: 'Descubra a quantidade para 1 porção (divisão) e multiplique pelo número de porções do pedido.',
      explicacao: `${linha.quantidade} ÷ ${r.porcoesBase} × ${porcoes} = ${fmtNumero(resposta)} ${ing.unidade}`,
    };
  },

  troco() {
    const r = sortear(catalogo.receitas);
    const porcoes = inteiroEntre(1, 6);
    const conta = r.precoPorcao * porcoes;
    const notas = [2000, 5000, 10000, 20000].filter((n) => n > conta);
    const pago = notas.length ? sortear(notas.slice(0, 2)) : conta + 5000;
    const resposta = (pago - conta) / 100;
    return {
      tema: 'Aritmética financeira',
      formato: 'numero',
      unidade: 'R$',
      tolerancia: 0.001,
      resposta,
      enunciado: `Um cliente pediu ${porcoes} porç${porcoes > 1 ? 'ões' : 'ão'} de ${r.nome} (${reais(r.precoPorcao)} cada) ` +
        `e pagou com ${reais(pago)}. Quanto de troco você deve devolver? (em reais, ex.: 12,50)`,
      dica: 'Calcule a conta (preço × porções) e depois: troco = valor pago − conta.',
      explicacao: `${reais(pago)} − ${reais(conta)} = ${reais(pago - conta)}`,
    };
  },

  fracao() {
    const pedacos = sortear([6, 8, 10, 12]);
    const servidos = inteiroEntre(1, pedacos - 1);
    const prato = sortear(['o Bolo da Vovó', 'a Lasanha de Forno', 'o Pudim do Verine']);
    return {
      tema: 'Frações',
      formato: 'fracao',
      resposta: [servidos, pedacos],
      enunciado: `Você cortou ${prato} em ${pedacos} pedaços iguais e ${servidos} já foram servidos à mesa. ` +
        'Que fração do prato foi servida? (ex.: 3/8)',
      dica: 'Numerador = pedaços servidos; denominador = total de pedaços. Frações equivalentes também valem.',
      explicacao: `${servidos}/${pedacos} (ou qualquer fração equivalente)`,
    };
  },

  regra_de_tres() {
    const ing = sortear(Object.values(catalogo.ingredientes).filter((i) => i.unidade !== 'un'));
    const fator = sortear([0.5, 1.5, 2.5, 3]);
    const desejado = ing.pacote * fator;
    const resposta = Math.round(ing.precoPacote * fator) / 100;
    return {
      tema: 'Regra de três',
      formato: 'numero',
      unidade: 'R$',
      tolerancia: 0.011,
      resposta,
      enunciado: `No fornecedor, um pacote de ${ing.pacote} ${ing.unidade} de ${ing.nome} custa ${reais(ing.precoPacote)}. ` +
        `Mantendo o mesmo preço por ${ing.unidade}, quanto custam ${fmtNumero(desejado)} ${ing.unidade}? (em reais)`,
      dica: `Monte a proporção: ${ing.pacote} ${ing.unidade} está para ${reais(ing.precoPacote)} assim como ${fmtNumero(desejado)} ${ing.unidade} está para x.`,
      explicacao: `x = ${fmtNumero(desejado)} × ${reais(ing.precoPacote)} ÷ ${ing.pacote} = ${reais(Math.round(ing.precoPacote * fator))}`,
    };
  },

  matriz() {
    const q = [0, 1].map(() => [0, 1, 2].map(() => inteiroEntre(1, 3)));
    const precos = [0, 1, 2].map(() => inteiroEntre(2, 6));
    const resposta = q.map((linha) => linha.reduce((soma, v, k) => soma + v * precos[k], 0));
    return {
      tema: 'Matrizes',
      formato: 'lista',
      tolerancia: 0.001,
      resposta,
      enunciado: 'Quantidade de pacotes por prato (colunas: Farinha, Ovos, Leite): ' +
        `Bolo [${q[0].join('  ')}] · Panqueca [${q[1].join('  ')}]. ` +
        `Preço de cada pacote em R$: [${precos.join('  ')}]. ` +
        'Calcule o custo de cada prato (matriz × vetor de preços). Responda: custo do Bolo; custo da Panqueca (ex.: 13; 14)',
      dica: 'Custo do prato = soma de (quantidade × preço) em cada coluna da linha do prato.',
      explicacao: `Bolo = ${resposta[0]}; Panqueca = ${resposta[1]}`,
    };
  },
};

const TEMAS = Object.keys(geradores);

/** Converte o texto digitado pelo jogador em número ("12,50", "R$ 7", "150 g", "1.234,5"). */
function lerNumero(texto) {
  let t = String(texto).toLowerCase().replace(/r\$|\s/g, '').replace(/(kg|g|ml|l|un)$/, '');
  if (t.includes(',') && t.includes('.')) t = t.replace(/\./g, '').replace(',', '.');
  else t = t.replace(',', '.');
  if (!/^-?\d+(\.\d+)?$/.test(t)) return null;
  return Number(t);
}

/** Corrige a resposta de acordo com o formato do desafio. Retorna null se o formato for inválido. */
function corrigir(desafio, respostaTexto) {
  const { formato, resposta, tolerancia = 0.001 } = desafio;
  if (formato === 'numero') {
    const n = lerNumero(respostaTexto);
    if (n === null) return null;
    return Math.abs(n - resposta) <= tolerancia;
  }
  if (formato === 'fracao') {
    const m = String(respostaTexto).trim().match(/^(\d+)\s*\/\s*(\d+)$/);
    if (!m || Number(m[2]) === 0) return null;
    // a/b == c/d  <=>  a·d == b·c  (aceita frações equivalentes)
    return Number(m[1]) * resposta[1] === Number(m[2]) * resposta[0];
  }
  if (formato === 'lista') {
    const partes = String(respostaTexto).split(';').map(lerNumero);
    if (partes.length !== resposta.length || partes.some((p) => p === null)) return null;
    return partes.every((p, i) => Math.abs(p - resposta[i]) <= tolerancia);
  }
  return null;
}

/** Remove os campos secretos antes de mandar o desafio ao navegador. */
const desafioPublico = (id, d) => ({
  id,
  tema: d.tema,
  formato: d.formato,
  unidade: d.unidade || null,
  enunciado: d.enunciado,
  dica: d.dica,
  partidaId: d.partidaId || null,
  expiraEm: new Date(d.expira).toISOString(),
});

/* =====================================================================
 * Rotas da API
 * ===================================================================== */
const rotas = [];
const rota = (metodo, padrao, acao) => rotas.push({ metodo, padrao, acao });

rota('GET', /^\/api\/status$/, () => ({
  status: 200,
  corpo: {
    ok: true,
    servico: "API do Verine's",
    versao: '1.0.0',
    ativoHaSegundos: Math.round(process.uptime()),
    receitas: catalogo.receitas.length,
    temasDeDesafio: TEMAS,
    rotas: rotas.map((r) => `${r.metodo} ${r.padrao.source.replace(/\\\//g, '/').replace(/[\^$]/g, '')}`),
  },
}));

rota('GET', /^\/api\/receitas$/, () => ({
  status: 200,
  corpo: { total: catalogo.receitas.length, receitas: catalogo.receitas.map(resumoReceita) },
}));

rota('GET', /^\/api\/receitas\/([a-z_]+)$/, ({ params, url }) => {
  const r = catalogo.receitas.find((x) => x.id === params[0]);
  if (!r) throw new ErroApi(404, 'RECEITA_NAO_ENCONTRADA', `Não existe receita com o id "${params[0]}".`);
  const bruto = url.searchParams.get('porcoes');
  const porcoes = bruto === null ? r.porcoesBase : Number(bruto);
  if (!Number.isInteger(porcoes) || porcoes < 1 || porcoes > 50) {
    throw new ErroApi(400, 'PORCOES_INVALIDAS', 'O número de porções deve ser um inteiro entre 1 e 50.');
  }
  return { status: 200, corpo: receitaAjustada(r, porcoes) };
});

rota('POST', /^\/api\/partidas$/, () => {
  const id = novoId();
  partidas.set(id, { pontos: 0, acertos: 0, respondidos: 0, salva: false, criadaEm: Date.now() });
  return { status: 201, corpo: { partidaId: id, pontos: 0, acertos: 0, respondidos: 0 } };
});

rota('GET', /^\/api\/desafios$/, ({ url }) => {
  let tema = url.searchParams.get('tema') || 'aleatorio';
  if (tema === 'aleatorio') tema = sortear(TEMAS);
  if (!geradores[tema]) {
    throw new ErroApi(400, 'TEMA_INVALIDO', `Tema desconhecido. Use: aleatorio, ${TEMAS.join(', ')}.`);
  }
  const partidaId = url.searchParams.get('partida');
  if (partidaId && !partidas.has(partidaId)) {
    throw new ErroApi(404, 'PARTIDA_NAO_ENCONTRADA', 'Partida não encontrada ou expirada. Comece uma nova.');
  }
  const id = novoId();
  const d = { ...geradores[tema](), chaveTema: tema, partidaId, respondido: false, expira: Date.now() + VALIDADE_DESAFIO_MS };
  desafios.set(id, d);
  return { status: 200, corpo: desafioPublico(id, d) };
});

rota('GET', /^\/api\/desafios\/(rec_[a-z_]+)$/, ({ params }) => {
  const rec = catalogo.desafiosRecuperacao[params[0]];
  if (!rec) throw new ErroApi(404, 'DESAFIO_NAO_ENCONTRADO', 'Desafio de recuperação não encontrado.');
  return {
    status: 200,
    corpo: { id: params[0], tema: rec.tema, formato: rec.formato, enunciado: rec.enunciado, dica: rec.dica, recuperacao: true },
  };
});

rota('POST', /^\/api\/desafios\/([\w-]+)\/resposta$/, async ({ params, req }) => {
  const corpo = await lerCorpoJson(req);
  const texto = limparTexto(corpo.resposta, 40);
  if (!texto) throw new ErroApi(422, 'RESPOSTA_VAZIA', 'Digite uma resposta antes de enviar.');

  // Desafios de recuperação de página manchada (fixos, vindos do jogo)
  const rec = catalogo.desafiosRecuperacao[params[0]];
  if (rec) {
    const correto = corrigir(rec, texto);
    if (correto === null) throw new ErroApi(422, 'FORMATO_INVALIDO', 'Responda apenas com um número (ex.: 120).');
    const ing = catalogo.ingredientes[rec.ingrediente];
    return {
      status: 200,
      corpo: correto
        ? { correto, mensagem: 'Dado recuperado! O livro de receitas foi atualizado.',
            recuperado: { receita: rec.receita, ingrediente: rec.ingrediente, quantidade: rec.resposta, unidade: ing.unidade } }
        : { correto, mensagem: 'Ainda não é esse valor. Releia a anotação do vovô e tente de novo.' },
    };
  }

  // Desafios gerados dinamicamente
  const d = desafios.get(params[0]);
  if (!d || d.expira < Date.now()) {
    throw new ErroApi(404, 'DESAFIO_NAO_ENCONTRADO', 'Este desafio não existe ou expirou. Gere um novo.');
  }
  if (d.respondido) throw new ErroApi(409, 'JA_RESPONDIDO', 'Este desafio já foi respondido. Gere o próximo!');

  const correto = corrigir(d, texto);
  if (correto === null) {
    const exemplos = { numero: 'um número (ex.: 12,50)', fracao: 'uma fração (ex.: 3/8)', lista: 'dois números separados por ";" (ex.: 13; 14)' };
    throw new ErroApi(422, 'FORMATO_INVALIDO', `Formato inválido. Responda com ${exemplos[d.formato]}.`);
  }
  d.respondido = true;

  let placar = null;
  const partida = d.partidaId && partidas.get(d.partidaId);
  if (partida) {
    partida.respondidos += 1;
    if (correto) {
      partida.acertos += 1;
      partida.pontos += PONTOS_POR_ACERTO;
    }
    placar = { pontos: partida.pontos, acertos: partida.acertos, respondidos: partida.respondidos };
  }
  return {
    status: 200,
    corpo: {
      correto,
      mensagem: correto ? 'Correto! Mandou bem na cozinha.' : 'Não foi dessa vez.',
      explicacao: d.explicacao,
      pontosGanhos: correto && partida ? PONTOS_POR_ACERTO : 0,
      placar,
    },
  };
});

rota('GET', /^\/api\/ranking$/, async ({ url }) => {
  const limite = Math.min(Math.max(parseInt(url.searchParams.get('limite'), 10) || 10, 1), 50);
  const lista = await lerLista(ARQ_RANKING);
  lista.sort((a, b) => b.pontos - a.pontos || b.acertos / b.respondidos - a.acertos / a.respondidos || a.data.localeCompare(b.data));
  return { status: 200, corpo: { total: lista.length, ranking: lista.slice(0, limite) } };
});

rota('POST', /^\/api\/ranking$/, async ({ req }) => {
  const corpo = await lerCorpoJson(req);
  const nome = limparTexto(corpo.nome, 20);
  if (nome.length < 2) throw new ErroApi(422, 'NOME_INVALIDO', 'O nome precisa ter entre 2 e 20 caracteres.');
  const partida = partidas.get(String(corpo.partidaId || ''));
  if (!partida) throw new ErroApi(404, 'PARTIDA_NAO_ENCONTRADA', 'Partida não encontrada ou expirada.');
  if (partida.respondidos === 0) throw new ErroApi(422, 'PARTIDA_VAZIA', 'Responda pelo menos um desafio antes de salvar.');
  if (partida.salva) throw new ErroApi(409, 'JA_SALVA', 'Esta partida já foi salva no ranking.');

  // A pontuação vem do servidor (partida), nunca do navegador — assim ninguém inventa pontos.
  const registro = {
    id: novoId(),
    nome,
    pontos: partida.pontos,
    acertos: partida.acertos,
    respondidos: partida.respondidos,
    data: new Date().toISOString(),
  };
  const lista = await lerLista(ARQ_RANKING);
  lista.push(registro);
  await gravarLista(ARQ_RANKING, lista);
  partida.salva = true;
  return { status: 201, corpo: registro };
});

const PERFIS = ['Estudante', 'Professor(a)', 'Jogador(a)', 'Outro'];

rota('POST', /^\/api\/mensagens$/, async ({ req }) => {
  const c = await lerCorpoJson(req);
  const msg = {
    nome: limparTexto(c.nome, 60),
    email: limparTexto(c.email, 120).toLowerCase(),
    perfil: limparTexto(c.perfil, 20),
    cep: String(c.cep ?? '').replace(/\D/g, ''),
    cidade: limparTexto(c.cidade, 60),
    uf: limparTexto(c.uf, 2).toUpperCase(),
    mensagem: limparTexto(c.mensagem, 500),
  };
  const erros = {};
  if (msg.nome.length < 2) erros.nome = 'Informe seu nome.';
  if (!/^[^\s@]+@[^\s@]+\.[^\s@]{2,}$/.test(msg.email)) erros.email = 'Informe um e-mail válido.';
  if (!PERFIS.includes(msg.perfil)) erros.perfil = 'Escolha um perfil da lista.';
  if (msg.cep && msg.cep.length !== 8) erros.cep = 'O CEP deve ter 8 dígitos.';
  if (msg.uf && !/^[A-Z]{2}$/.test(msg.uf)) erros.uf = 'UF inválida.';
  if (msg.mensagem.length < 10) erros.mensagem = 'A mensagem precisa ter pelo menos 10 caracteres.';
  if (Object.keys(erros).length) {
    const e = new ErroApi(422, 'DADOS_INVALIDOS', 'Alguns campos precisam ser corrigidos.');
    e.campos = erros;
    throw e;
  }
  const registro = { id: novoId(), ...msg, recebidaEm: new Date().toISOString() };
  const lista = await lerLista(ARQ_MENSAGENS);
  lista.push(registro);
  await gravarLista(ARQ_MENSAGENS, lista);
  // Devolve só o necessário (não ecoa o e-mail de volta)
  return { status: 201, corpo: { id: registro.id, recebidaEm: registro.recebidaEm, totalMensagens: lista.length } };
});

rota('GET', /^\/api\/mensagens\/estatisticas$/, async () => {
  const lista = await lerLista(ARQ_MENSAGENS);
  const porPerfil = Object.fromEntries(PERFIS.map((p) => [p, 0]));
  const cidades = new Set();
  for (const m of lista) {
    if (m.perfil in porPerfil) porPerfil[m.perfil] += 1;
    if (m.cidade) cidades.add(`${m.cidade}/${m.uf}`);
  }
  return { status: 200, corpo: { total: lista.length, porPerfil, cidadesDiferentes: cidades.size } };
});

rota('GET', /^\/api\/jogo$/, async () => {
  try {
    const info = await fsp.stat(ARQ_JOGO);
    return {
      status: 200,
      corpo: {
        disponivel: true,
        arquivo: path.basename(ARQ_JOGO),
        url: "./verines_site/Verine'sGame.zip",
        tamanhoBytes: info.size,
        atualizadoEm: info.mtime.toISOString(),
        plataforma: 'PC (projeto Godot Engine)',
      },
    };
  } catch {
    return { status: 200, corpo: { disponivel: false } };
  }
});

/* =====================================================================
 * Arquivos estáticos do site
 * ===================================================================== */
const TIPOS = {
  '.html': 'text/html; charset=utf-8', '.css': 'text/css; charset=utf-8', '.js': 'text/javascript; charset=utf-8',
  '.json': 'application/json; charset=utf-8', '.png': 'image/png', '.jpg': 'image/jpeg', '.jpeg': 'image/jpeg',
  '.ico': 'image/x-icon', '.svg': 'image/svg+xml', '.zip': 'application/zip', '.pdf': 'application/pdf', '.md': 'text/plain; charset=utf-8',
};

async function servirArquivo(req, res, caminhoUrl) {
  let relativo;
  try {
    relativo = decodeURIComponent(caminhoUrl);
  } catch {
    return enviarJson(res, 400, { erro: { codigo: 'URL_INVALIDA', mensagem: 'Endereço inválido.' } });
  }
  if (relativo.endsWith('/')) relativo += 'index.html';
  const absoluto = path.resolve(RAIZ_SITE, '.' + relativo);
  // Bloqueia "../" para fora do projeto e a pasta do servidor (dados das mensagens).
  if (!absoluto.startsWith(RAIZ_SITE + path.sep) || absoluto.startsWith(__dirname)) {
    res.writeHead(403, { 'Content-Type': 'text/plain; charset=utf-8' });
    return res.end('Acesso negado');
  }
  try {
    const info = await fsp.stat(absoluto);
    if (!info.isFile()) throw new Error('não é arquivo');
    res.writeHead(200, {
      'Content-Type': TIPOS[path.extname(absoluto).toLowerCase()] || 'application/octet-stream',
      'Content-Length': info.size,
    });
    if (req.method === 'HEAD') return res.end();
    fs.createReadStream(absoluto).pipe(res);
  } catch {
    res.writeHead(404, { 'Content-Type': 'text/plain; charset=utf-8' });
    res.end('Arquivo não encontrado');
  }
}

/* =====================================================================
 * Servidor
 * ===================================================================== */
const servidor = http.createServer(async (req, res) => {
  const url = new URL(req.url, `http://${req.headers.host || 'localhost'}`);
  const inicio = Date.now();

  if (!url.pathname.startsWith('/api/')) {
    if (req.method !== 'GET' && req.method !== 'HEAD') {
      res.writeHead(405);
      return res.end();
    }
    return servirArquivo(req, res, url.pathname);
  }

  aplicarCors(res);
  if (req.method === 'OPTIONS') {
    res.writeHead(204);
    return res.end();
  }

  try {
    const doCaminho = rotas.filter((r) => r.padrao.test(url.pathname));
    if (!doCaminho.length) throw new ErroApi(404, 'ROTA_NAO_ENCONTRADA', `Rota ${url.pathname} não existe. Veja GET /api/status.`);
    const encontrada = doCaminho.find((r) => r.metodo === req.method);
    if (!encontrada) throw new ErroApi(405, 'METODO_NAO_PERMITIDO', `Use ${doCaminho.map((r) => r.metodo).join(' ou ')} nesta rota.`);
    const params = url.pathname.match(encontrada.padrao).slice(1);
    const { status, corpo } = await encontrada.acao({ req, url, params });
    enviarJson(res, status, corpo);
  } catch (erro) {
    if (erro instanceof ErroApi) {
      enviarJson(res, erro.status, { erro: { codigo: erro.codigo, mensagem: erro.message, campos: erro.campos } });
    } else {
      console.error(erro);
      enviarJson(res, 500, { erro: { codigo: 'ERRO_INTERNO', mensagem: 'Erro inesperado no servidor.' } });
    }
  } finally {
    console.log(`${req.method} ${url.pathname}${url.search} → ${res.statusCode} (${Date.now() - inicio} ms)`);
  }
});

servidor.listen(PORT, () => {
  console.log(`\n🍳 Verine's rodando em http://localhost:${PORT}`);
  console.log(`   API disponível em http://localhost:${PORT}/api/status\n`);
});
