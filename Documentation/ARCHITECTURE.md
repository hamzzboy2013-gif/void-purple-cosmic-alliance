# VOID PURPLE - Architecture Documentation

## System Architecture

### Core Managers (Singleton Pattern)

1. **GameManager** - Master controller
   - Manages game states
   - Coordinates all systems
   - Handles scene transitions

2. **InputManager** - Input handling
   - Processes player input
   - Broadcasts input events
   - Supports both keyboard and mobile controls

3. **DataManager** - Data access layer
   - Loads ally/enemy/world data
   - Manages databases
   - Scriptable objects storage

## Gameplay Systems

### Combat System
- **PlayerCombat** - Player attack logic
- **EnemyAI** - Enemy behavior
- **CombatManager** - Combat orchestration

### Progression System
- **PlayerStats** - Player stat management
- **ProgressionManager** - Level/world progression
- **SaveSystem** - Data persistence

### Ally System
- **AllyManager** - Ally roster management
- **AllyData** - Ally attributes
- **Recruitment** - Boss defeat rewards

## Data Flow

```
Input → InputManager → Player/Combat → GameManager → UI
                         ↓
                    Save System → PlayerPrefs
```

## Mobile Optimization

- Object pooling for enemies
- Efficient physics with simplified shapes
- Mobile joystick input system
- Optimized UI with Canvas batching

## Extensibility

All systems are designed to be extended:
- Add new skills by inheriting from SkillBase
- Add new enemies by extending EnemyManager
- Add new UI screens by extending UICanvas
- Add new worlds in WorldData array
