class_name ConfirmDialog
extends MenuScreen
## Une question avant un geste qu'on ne rattrape pas (quitter sans sauvegarder) : « Non »
## a le focus, pour qu'un appui distrait ne fasse rien perdre.

## Clé de traduction de la question.
var question := ""


func build() -> void:
	add_text(tr(question))
	add_button("no", "CONFIRM_NO")
	add_button("yes", "CONFIRM_YES")
