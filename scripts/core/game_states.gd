class_name GameStates
extends RefCounted
## Estados gerais do jogo (seção 3.2 da documentação).
## Cada estado corresponde a um painel da interface em main.gd.

enum Id {
	MAIN_MENU,
	INTRO,
	RESTAURANT,
	ACTIVE_ORDER,
	INVESTIGATION,
	RECIPE_BOOK,
	MATH_CHALLENGE,
	PREPARATION,
	DELIVERY,
	ADMINISTRATION,
	RESULT,
	ENDING,
}
