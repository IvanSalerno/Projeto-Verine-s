# Verine's — protótipo do site oficial

Site responsivo feito com HTML, CSS e JavaScript puro. As imagens são espaços reservados até você enviar as capturas reais do jogo.

## Como abrir
1. Extraia o ZIP.
2. Abra `index.html` no navegador.
3. Para editar, abra a pasta no VS Code.

## Como colocar suas imagens
1. Salve as imagens na pasta `assets/`.
2. Abra `script.js` e preencha os caminhos do objeto `images`. Exemplo:

```js
const images = {
  hero: 'assets/cenario-principal.png',
  restaurant: 'assets/restaurante.png',
  'gallery-1': 'assets/gameplay-01.png',
  'gallery-2': 'assets/gameplay-02.png',
  'gallery-3': 'assets/personagens.png',
  'gallery-4': 'assets/restaurante-02.png',
  'gallery-5': 'assets/desafio.png',
  'gallery-6': 'assets/historia.png',
  story: 'assets/cena-historia.png'
};
```

Use os nomes exatos dos seus arquivos. Campos ainda sem imagem podem continuar como `''`.

## Cores
No início de `style.css`, as variáveis da paleta são `--stone`, `--brown`, `--sand`, `--gold` e `--cream`.

Textos e nomes da equipe são editáveis. Os links de download, redes sociais e formulários ainda não estão conectados.
