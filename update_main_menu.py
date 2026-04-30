import sys

file_path = 'd:\\program\\godot\\project_terminus\\scenes\\start_menu\\main_menu.tscn'
with open(file_path, 'r', encoding='utf-8') as f:
    lines = f.readlines()

new_lines = []
skip = False
ext_resource_added = False

for line in lines:
    if line.startswith('[ext_resource') and not ext_resource_added:
        pass
    if line.startswith('[sub_resource') and not ext_resource_added:
        new_lines.append('[ext_resource type="PackedScene" uid="uid://cpog3fskyl4m7" path="res://scenes/main_world/pause.tscn" id="6_pause"]\n')
        ext_resource_added = True
    
    if line.startswith('[node name="OptionsPanel"'):
        skip = True
    elif line.startswith('[node name="AboutPanel"'):
        if skip:
            skip = False
            new_lines.append('[node name="Pause" parent="." instance=ExtResource("6_pause")]\n')
            new_lines.append('\n')
            
    if line.startswith('[connection signal="pressed" from="OptionsPanel/'):
        continue

    if not skip:
        new_lines.append(line)

with open(file_path, 'w', encoding='utf-8') as f:
    f.writelines(new_lines)
