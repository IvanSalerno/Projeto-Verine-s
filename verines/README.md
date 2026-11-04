# Verine's — protótipo Godot 4 (GDScript)

## Como abrir
1. Abra a pasta no Godot 4.3+ (Importar → project.godot). Aguarde o editor indexar os `class_name`.
2. Aperte F5 (cena principal: `scenes/main.tscn`).

## Arquitetura
- Autoloads (ordem importa): `GameData` (catálogo) → `Game` (dinheiro, estoque, melhorias) → `Flow` (estados e regras do atendimento).
- `scripts/core`: Units, Money (centavos), AnswerValidator, ChallengeFactory, GameStates.
- `scripts/data`: Ingredient, Recipe (dados originais), AdjustedRecipe (ajuste por pedido), Clue, Order, Dish, Upgrade, MathChallenge.
- `scripts/ui/main.gd`: toda a interface por código, só mouse (teclado numérico na tela).

## Para a equipe definir
Catálogo definitivo, balanceamento (valores em `Flow`), história/desfecho, tempo e pedidos simultâneos (v2).

## Imagens
Copie as imagens dos clientes para `assets/clientes/` com estes nomes:
- `cliente_vermelho.png` (Cliente, casaco com camisa vermelho.png)
- `cliente_azul.png` (Cliente_loiro_camisa_azul.png)
- `cliente_amarelo.png` (Cliente_moleton_amarelo.png)
Sem as imagens, o jogo mostra blocos coloridos no lugar. Depois de copiar, abra o editor do Godot para ele importar os arquivos.
Cena do restaurante: `scenes/restaurant_view.tscn` (edite os blocos no editor).

## Placar e dias
- Placar de pontos no canto superior direito; contador de dias no centro superior.
- O dia fecha a cada 2 pedidos concluídos (`Flow.ORDERS_PER_DAY`). No fim do dia há um desafio de gestão opcional (bônus em dinheiro e pontos).
- Recorde salvo em `user://verines.cfg`.
- Matérias: razão/proporção, unidades, geometria, estatística, probabilidade, combinatória, equações, função, sistema, PA, juros compostos, raiz quadrada e matrizes (`scripts/core/math_topics.gd`).

## Páginas (v6)
- Salão (`scenes/salao_view.tscn`): atendimento, investigação e entrega.
- Cozinha (`scenes/cozinha_view.tscn`): ajuste de quantidades (desafios) e preparo.
- Despensa e escritório (`scenes/despensa_view.tscn`): estoque, compras, melhorias.
- Menu inicial: Novo jogo, Continuar, Configurações, Créditos. Menu de jogo (☰ no canto superior esquerdo): Salvar, Configurações, Menu principal.
- Salvamento em `user://verines_save.json` (manual pelo ☰ e automático a cada novo dia). Créditos: edite `scripts/data/credits.gd`.
- Atenção: esta versão adiciona o autoload `Settings` ao project.godot.

## Imagens dos cenários
Coloque em `assets/cenarios/` (PNG, formato bem largo, ideal 1248×230 px ou o dobro, 2496×460):
- `salao.png`, `cozinha.png`, `despensa.png`
Se o arquivo existir, ele vira o fundo da página e os blocos coloridos somem. Sem o arquivo, a blocagem continua.

## Imagens (v8) — pasta assets/cenarios/
- `salao.png`: atendimento ao cliente (Salão)
- `caixa_registradora.png`: pagamento e troco (entrega)
- `cozinha.png`: ajuste das quantidades e prato pronto
- `preparacao.png`: etapas de preparo (separar, misturar, montar, finalizar)
- `fogao.png`: etapas com fogo (assar, cozinhar, fritar, aquecer, calda)
- `livro_receitas.png` (ou `livro de receitas.png`): fundo do menu inicial
- `despensa.png`: opcional (sem ela, a Despensa usa blocos)
