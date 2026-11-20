# Verine’s — Site Oficial

**Site institucional do projeto Verine’s**, desenvolvido para apresentar a proposta do jogo, sua narrativa, jogabilidade, identidade visual e processo de desenvolvimento.

## Sobre o projeto

Verine’s é um projeto de jogo digital 2D que combina desafios matemáticos com elementos de administração de restaurante.

Na história, o protagonista recebe como herança um restaurante abandonado que pertenceu ao seu avô. A partir disso, inicia uma jornada para recuperar o estabelecimento e preservar o legado familiar.

O jogo busca aproximar conteúdos matemáticos de situações práticas, envolvendo atividades como preparação de receitas, administração de recursos e melhorias no restaurante.

O site foi desenvolvido para divulgar o projeto, apresentar suas características e centralizar informações importantes para os visitantes.

## Objetivos do site

- Apresentar o universo e a proposta educativa de Verine’s.
- Divulgar a história e os elementos narrativos do jogo.
- Demonstrar as mecânicas e funcionalidades.
- Disponibilizar uma galeria de imagens do projeto.
- Apresentar a equipe responsável pelo desenvolvimento.
- Oferecer acesso ao download do jogo quando houver uma versão finalizada e testada.

## Tecnologias utilizadas

| Tecnologia | Finalidade |
|---|---|
| HTML5 | Estruturação e organização do conteúdo. |
| CSS3 | Estilização, identidade visual e responsividade. |
| JavaScript | Implementação de funcionalidades e interatividade. |
| Node.js (módulo `http`, sem bibliotecas) | API REST própria do Verine's e servidor dos arquivos do site. |
| Fetch API | Comunicação do site com a API própria e com APIs públicas (AwesomeAPI e ViaCEP). |
| Godot Engine | Desenvolvimento e exportação do jogo Verine’s. |

## Identidade visual

A identidade visual foi planejada para transmitir uma atmosfera acolhedora, relacionada à culinária, à memória familiar e ao ambiente de um restaurante.

### Paleta de cores

| Cor | Código HEX | Aplicação |
|---|---|---|
| Bege acinzentado | `#CFCDBE` | Fundos de apoio e áreas neutras. |
| Marrom | `#7B3C15` | Títulos, navegação e destaques. |
| Bege amarronzado | `#C3B18E` | Cartões e blocos intermediários. |
| Amarelo dourado | `#FFDD73` | Botões, ícones e chamadas importantes. |
| Creme claro | `#FFEDCC` | Fundos claros e textos em áreas escuras. |

### Tipografia

O projeto utiliza duas famílias tipográficas:

- **Playfair Display:** utilizada em títulos e chamadas principais, proporcionando personalidade e identidade visual.
- **DM Sans:** utilizada em textos corridos, menus, botões e elementos de interface, priorizando a legibilidade.

## Estrutura do site

O site está organizado nas seguintes seções:

- **Home:** apresentação inicial do projeto e chamada principal.
- **Sobre o jogo:** introdução à proposta e ao universo de Verine’s.
- **Jogabilidade:** apresentação das mecânicas e dos desafios matemáticos.
- **Cozinha de Testes:** livro de receitas, desafios matemáticos com ranking e mercado com câmbio real (usa APIs).
- **Galeria:** espaço destinado às capturas de tela e imagens do jogo.
- **História:** apresentação da narrativa e do legado familiar.
- **Download:** área destinada à disponibilização do jogo.
- **Desenvolvimento e equipe:** informações sobre o processo de criação e os integrantes.
- **Contato:** formulário com preenchimento de cidade pelo CEP e envio para a API.
- **Rodapé:** informações finais e links úteis.

## Responsividade e experiência do usuário

O site foi planejado para funcionar em diferentes dispositivos, incluindo computadores, tablets e celulares.

A organização dos elementos busca proporcionar:

- Navegação simples e intuitiva.
- Organização visual das informações.
- Adaptação a diferentes tamanhos de tela.
- Hierarquia entre títulos, textos e elementos interativos.
- Contraste adequado para facilitar a leitura.

## Galeria e recursos visuais

O projeto prevê a utilização de imagens reais do jogo, ilustrações e capturas de tela.

Os espaços visuais foram planejados para permitir a inclusão posterior desses materiais, acompanhando a evolução do desenvolvimento de Verine’s.

Os arquivos de imagem devem ser organizados em diretórios específicos, como `assets`, facilitando sua localização e manutenção.

## Download do jogo

A seção de download será disponibilizada quando o jogo estiver exportado pela Godot Engine e possuir uma versão testada e pronta para distribuição.

A disponibilização deverá informar a plataforma compatível e incluir orientações de execução, quando necessário.

Enquanto não houver uma versão distribuível, a seção permanecerá como espaço reservado ou apresentará uma mensagem informando que o jogo ainda está em desenvolvimento.

## Equipe de desenvolvimento

Projeto desenvolvido no contexto acadêmico do Instituto Federal de Educação, Ciência e Tecnologia de São Paulo (IFSP).

**Integrantes:**
- Ana Clara
- Cauê Celestino
- Gabriel das Graças
- Isabella Bartu
- Ivan Salerno

## Considerações finais

O site de Verine’s foi desenvolvido com o propósito de fortalecer a identidade do projeto e apresentar sua proposta de maneira organizada, acessível e visualmente coerente.

A combinação entre HTML5, CSS3 e JavaScript permite construir uma experiência interativa e responsiva, enquanto a identidade visual reforça os elementos narrativos e a atmosfera do jogo.

O projeto poderá receber atualizações conforme o desenvolvimento do jogo avance, incluindo novas imagens, informações, funcionalidades e a futura disponibilização para download.

## Como executar o site com a API

A API própria foi feita apenas com módulos nativos do Node.js, então **não é preciso instalar nada além do Node.js (versão 18 ou superior)**.

1. Abra um terminal na pasta principal do projeto (onde está o `index.html`).
2. Rode `node server/server.js` (ou `npm start`).
3. Acesse **http://localhost:3000** no navegador.

O mesmo servidor entrega o site e a API. Se o `index.html` for aberto direto pelo arquivo (ou pelo Live Server), o site continua funcionando e tenta usar a API em `http://localhost:3000`; se o servidor estiver desligado, cada seção mostra um aviso explicando como ligá-lo e um botão "Tentar novamente".

## Integração com APIs

O site usa três APIs reais. Todas as chamadas passam por `verines_site/api.js`, que usa a Fetch API, cancela pedidos que demoram demais (timeout), trata erros de rede, erros HTTP e respostas em formato inválido, e registra tudo no **Monitor de APIs** (botão "⇄ APIs" no canto da tela), onde dá para ver método, endereço, status, tempo e o JSON enviado e recebido.

### 1. API do Verine’s (própria) — `server/server.js`

Os dados das receitas, ingredientes e desafios são os mesmos do jogo (`Verine's Game/scripts/autoload/game_data.gd`), copiados para `server/data/catalogo.json`. O ranking e as mensagens ficam salvos em `server/data/ranking.json` e `server/data/mensagens.json` (criados automaticamente).

| Método | Rota | O que faz | Usado em |
|---|---|---|---|
| GET | `/api/status` | Saúde da API e lista de rotas | Selo "Servidor online" |
| GET | `/api/receitas` | Resumo do livro de receitas | Lista de receitas |
| GET | `/api/receitas/:id?porcoes=N` | Receita com quantidades e custos recalculados para N porções | Detalhe da receita |
| GET | `/api/desafios/:id` | Enunciado do desafio de uma página manchada | Recuperar ingrediente |
| POST | `/api/partidas` | Inicia uma partida (placar guardado no servidor) | Desafios |
| GET | `/api/desafios?tema=X&partida=ID` | Gera um desafio novo (proporção, troco, frações, regra de três, matrizes) | Desafios |
| POST | `/api/desafios/:id/resposta` | Corrige a resposta no servidor e atualiza o placar | Desafios e páginas manchadas |
| GET | `/api/ranking?limite=10` | Melhores pontuações | Ranking |
| POST | `/api/ranking` | Salva a pontuação da partida | Ranking |
| POST | `/api/mensagens` | Valida e salva a mensagem do formulário | Contato |
| GET | `/api/mensagens/estatisticas` | Total de mensagens, cidades e perfis | Contato |
| GET | `/api/jogo` | Tamanho e data do arquivo do jogo | Download |

Decisões importantes:

- **A resposta certa nunca é enviada ao navegador.** O servidor guarda a resposta e só devolve se o jogador acertou. Assim, não dá para descobrir a resposta pelo código da página.
- **A pontuação do ranking é calculada pelo servidor**, a partir da partida. O navegador envia só o nome, então ninguém consegue inventar pontos.
- Respostas de erro seguem sempre o mesmo formato, com o status HTTP correto (400, 404, 405, 409, 413, 415, 422):
  `{ "erro": { "codigo": "PORCOES_INVALIDAS", "mensagem": "O número de porções deve ser um inteiro entre 1 e 50." } }`
- O servidor valida tudo de novo (o navegador também valida, mas isso pode ser burlado), limita o tamanho dos dados recebidos e bloqueia o acesso à pasta `server/` pelo navegador.

Exemplo de teste no terminal:

```bash
curl "http://localhost:3000/api/receitas/bolo?porcoes=6"
curl -X POST -H "Content-Type: application/json" -d '{"resposta":"150"}' http://localhost:3000/api/desafios/rec_lasanha_queijo/resposta
```

### 2. AwesomeAPI — cotação do dólar e do euro

`GET https://economia.awesomeapi.com.br/json/last/USD-BRL,EUR-BRL` — gratuita e sem chave. Na aba **Mercado do dia**, a cotação real é usada para gerar desafios de compra de ingredientes importados (converter preços e calcular quantas unidades cabem no orçamento). Sem chave, a própria AwesomeAPI pode devolver o valor com até 1 minuto de atraso, o que não atrapalha o uso.

### 3. ViaCEP — endereço pelo CEP

`GET https://viacep.com.br/ws/{cep}/json/` — gratuita e sem chave. No formulário de contato, ao completar o CEP, a cidade e a UF são preenchidas sozinhas. CEP inexistente (`{"erro": true}`) e falha de conexão mostram avisos, e os campos continuam editáveis.

Nenhuma chave de API é usada nem exposta no código.

## JavaScript e manipulação do DOM

| Arquivo | Responsabilidade |
|---|---|
| `verines_site/api.js` | Camada de comunicação HTTP (Fetch, timeout, erros, monitor). |
| `verines_site/script.js` | Menu responsivo, destaque da seção atual no menu, galeria com lightbox, download. |
| `verines_site/cozinha.js` | Seções que usam APIs: receitas, desafios, ranking, mercado, contato e monitor. |

Recursos do DOM usados: `querySelector`, `querySelectorAll`, `getElementById`, `textContent`, `classList` (`add`, `remove`, `toggle`), `createElement`/`append`/`replaceChildren`/`remove`, `addEventListener` (click, input, submit, keydown), `dataset`, atributos ARIA, `IntersectionObserver` e `localStorage` (guarda os ingredientes recuperados, como o progresso do jogo). O HTML é montado com `createElement` e `textContent`, e não com `innerHTML`, o que evita injeção de código vindo das APIs.

## Correções feitas

- Galeria: o lightbox abria imagens com caminho errado (faltava `verines_site/`); agora usa o `src` da própria imagem e ganhou setas e navegação pelo teclado.
- Download: o script tentava escrever em `#download-note`, que não existia, e gerava erro no console.
- HTML: removidas `</div>` sobrando e estilos repetidos em cada `<img>`, que foram para o CSS.
- Responsividade: menu "hambúrguer" até 1100 px (o menu tem 8 links), polaroid que passava da tela no celular, selo do hero sobre o rótulo da imagem, formulários e tabelas adaptados. Testado em 1280, 1024, 820, 600, 390 e 320 px sem rolagem horizontal.
- Acessibilidade: link "Pular para o conteúdo", foco visível, abas navegáveis por teclado, mensagens com `role="status"`.

> Observação: o arquivo `verines_site.zip` na pasta principal é uma cópia antiga (outubro) do site e não foi alterado.

---

**Verine’s — Uma jornada de sabores, desafios e descobertas.**
