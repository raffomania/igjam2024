extends Node2D


var scores: Dictionary

var score_text = preload("res://Scoring/score_text.tscn")

var childs = {}

var colors = {
    0: 'Cyan',
    1: 'Orange',
    2: 'Purple',
    3: 'Pink',
    4: 'Green',
    5: 'Yellow',
    6: 'Cyan',
    7: 'Orange',
    8: 'Purple',
}


func _ready() -> void:
    scores = {}
    
func update_player_score_label(text: RichTextLabel, player: Player, index: int) -> void:
    text.text = 'Player %s:   %s \n' % [colors[index], scores[index]]
    text.position = Vector2(0, 50 * (index + 3))
    text.modulate = player.player_color

func init_scores() -> void:
    for node in get_tree().get_nodes_in_group('players'):
        var player = node as Player
        # Offset index by 2 to prevent negative numbers
        var index = player.controller_device_index + 2

        if !scores.keys().has(index):
            scores[index] = 0

        var label
        # Create score label if none exists for the player
        if not childs.keys().has(index):
            label = score_text.instantiate()
            childs[index] = label

        label = childs[index]
        update_player_score_label(label as RichTextLabel, player, index)

        # Add score label to scoring system if not done already
        if label.get_parent() == null:
            add_child(label)

        queue_redraw()


func increase_score(player: Player):
    var index = player.controller_device_index + 2
    if scores.keys().has(index):
        scores[index] += 1
    else:
        scores[index] = 1
    init_scores()
