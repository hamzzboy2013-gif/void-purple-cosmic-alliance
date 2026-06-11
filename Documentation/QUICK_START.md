# Quick Start Guide

## Installation

1. Clone repository
   ```bash
   git clone https://github.com/hamzzboy2013-gif/void-purple-cosmic-alliance.git
   cd void-purple-cosmic-alliance
   ```

2. Open in Unity 2022.3 LTS or higher

3. Load the MainScene
   ```
   Assets/Scenes/MainScene.unity
   ```

## First Run

1. Press Play in the editor
2. Use WASD to move
3. Use mouse or touchscreen for combat:
   - Left click: Attack
   - E: Skill 1
   - R: Skill 2
   - Space: Dash
   - Q: Ultimate

## Mobile Testing

1. Build and Run to Android/iOS device
2. Use on-screen joystick for movement
3. Tap buttons for actions
4. Hold Ultimate button when charged

## Adding New Content

### New Enemy Type

1. Create enemy prefab with EnemyManager script
2. Add data to EnemyDatabase
3. Spawn in level

### New Ally

1. Add AllyData to allyDatabase
2. Create skills in SkillData array
3. Add to boss rewards

### New World

1. Create WorldData with theme
2. Add BossData
3. Configure in ProgressionManager
4. Create level scene

## Debugging

- All managers log to console
- Use Debug.Log extensively
- Unity Inspector shows all serialized properties
- Profiler available in Window > Analysis > Profiler

## Performance Tips

- Use object pooling for enemy spawning
- Optimize physics with simplified colliders
- Limit particle effects on mobile
- Use LOD (Level of Detail) for models
- Batch UI rendering with Canvas groups
