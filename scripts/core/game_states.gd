class_name GameStates
extends RefCounted
## Estados do jogo (cada um é um painel da interface) e lugares (páginas com cena própria).

enum Id {
	MAIN_MENU,
	INTRO,
	RESTAURANT,
	ACTIVE_ORDER,
	INVESTIGATION,
	RECIPE_BOOK,
	MATH_CHALLENGE,
	KITCHEN,
	DELIVERY,
	ADMINISTRATION,
	RESULT,
	DAY_SUMMARY,
	SETTINGS,
	CREDITS,
	ENDING,
}

## Páginas do restaurante, com visão e navegação próprias.
enum Place { SALAO, COZINHA, DESPENSA }

## Lugar ao qual o estado pertence (-1 = nenhum).
static func place_of(s: int) -> int:
	match s:
		Id.RESTAURANT, Id.ACTIVE_ORDER, Id.INVESTIGATION, Id.DELIVERY, Id.RESULT, Id.DAY_SUMMARY:
			return Place.SALAO
		Id.KITCHEN:
			return Place.COZINHA
		Id.ADMINISTRATION:
			return Place.DESPENSA
	return -1

## A barra de navegação (Salão/Cozinha/Despensa) só aparece nestes estados.
static func can_navigate(s: int) -> bool:
	return place_of(s) != -1 and not (s in [Id.RESULT, Id.DAY_SUMMARY])
