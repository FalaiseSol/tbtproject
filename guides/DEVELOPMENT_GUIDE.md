# Development Guide for TBT Project

## Recommended Game Engine (FREE)

### **Godot Engine** ⭐ **RECOMMENDED**

- **Why**: Completely free, open-source, no royalties
- **Best for**: 2D/3D games, turn-based systems, indie projects
- **Pros**:
  - Lightweight and fast
  - GDScript (Python-like) is easy to learn
  - Great for ATB systems and turn-based combat
  - Built-in multiplayer networking
  - Active community
- **Cons**: Smaller asset store than Unity/Unreal
- **Download**: https://godotengine.org/

#### **Godot Standard vs Godot .NET - Which to Choose?**

**Godot Engine (Standard)** ⭐ **RECOMMENDED FOR YOU**

- **Scripting Language**: GDScript (Python-like syntax)
- **Pros**:
  - ✅ Easier to learn (Python-like syntax)
  - ✅ Faster startup and compilation
  - ✅ Better documentation and tutorials
  - ✅ More community examples in GDScript
  - ✅ No additional dependencies
  - ✅ Perfect for your project size
- **Cons**:
  - Slightly slower than C# for very complex calculations (won't matter for your game)
- **Best for**: Beginners, indie games, turn-based RPGs like yours

**Godot Engine - .NET**

- **Scripting Language**: C# (requires .NET runtime)
- **Pros**:
  - ✅ Better performance for heavy calculations
  - ✅ If you already know C#
  - ✅ Better IDE support (Rider, Visual Studio)
- **Cons**:
  - ❌ Requires .NET runtime installation
  - ❌ Steeper learning curve if new to C#
  - ❌ Larger download size
  - ❌ Fewer beginner tutorials
  - ❌ Slightly more complex setup
- **Best for**: Developers already familiar with C#, enterprise projects

**Recommendation**: Start with **Godot Engine (Standard)** - it's simpler, has better learning resources, and is perfectly capable for your turn-based RPG. You can always switch to .NET later if needed, but for your project, GDScript will be more than sufficient.

**Note on AI Assistance**: AI coding assistants (like Cursor's AI) work equally well with both GDScript and C#. In fact, GDScript might be slightly easier for AI to help with because:

- More examples and tutorials available online (which AI can reference)
- Simpler syntax means cleaner, more readable code
- Better documentation coverage
- More community code samples to learn from

**Bottom line**: Don't choose .NET just for AI assistance - I can help you with either language equally well! Choose based on what's best for your project and learning curve.

### **Unity** (Alternative)

- **Why**: Industry standard, massive community
- **Pros**: Huge asset store, extensive tutorials
- **Cons**:
  - New pricing model (free for individuals under $100k revenue, but more complex)
  - Heavier than Godot
  - Requires Unity account

### **Unreal Engine** (Alternative)

- **Why**: AAA-quality graphics, free for indie
- **Pros**: Best graphics, Blueprint visual scripting
- **Cons**:
  - Overkill for low-poly style
  - Steeper learning curve
  - Larger file size

## Development Approach

### Phase 1: Prototype (Weeks 1-4)

1. **Core Combat System**

   - Basic ATB turn system
   - Simple character stats (HP, Mana, Speed)
   - One basic attack and one skill
   - Test with 2-3 characters

2. **Character System**
   - Basic stat system
   - Simple skill tree (even if just 3-4 skills)
   - Equipment slots (start with 3-4 slots)

### Phase 2: Core Systems (Weeks 5-12)

3. **Exploration**

   - Simple overworld movement
   - Basic city hub
   - One simple dungeon (not procedural yet)

4. **Progression**
   - Loot drops
   - Equipment system
   - Basic skill/magic trees

### Phase 3: Content & Polish (Months 4+)

5. **Procedural Generation**

   - Overworld paths
   - Dungeon generation

6. **Multiplayer**

   - Start with local multiplayer
   - Then add networking

7. **Art & Atmosphere**
   - Pixel art sprites and animations
   - Tile-based environments
   - UI design

## Free Tools & Resources

### 2D Art & Assets

- **Aseprite** (PAID/FREE) - Pixel art editor
  - Perfect for 2D sprites and animations
  - Industry standard for pixel art
  - https://www.aseprite.org/

- **Free Asset Sources**:
  - OpenGameArt.org (2D sprites, tilesets)
  - Itch.io (free pixel art assets)
  - Kenney.nl (free 2D game assets)
  - Craftpix.net (free pixel art packs)

### Code & Version Control

- **Git** (FREE) - Already using this ✅
- **GitHub** (FREE) - Host your repository
- **VS Code** (FREE) - Code editor

### Audio

- **Audacity** (FREE) - Sound editing
- **Freesound.org** - Free sound effects
- **Incompetech** - Free music (with attribution)

### UI/Design

- **GIMP** (FREE) - Image editing
- **Aseprite** (PAID) - Pixel art editor (recommended)

## Project Structure Recommendation

```
tbtproject/
├── docs/              # Design documents, game design docs
├── assets/            # Game assets (models, textures, sounds)
│   ├── models/
│   ├── textures/
│   ├── audio/
│   └── ui/
├── src/               # Source code (if using engine)
├── prototypes/        # Quick prototypes to test ideas
└── README.md
```

## Learning Resources (FREE)

### Godot Specific

- Official Godot Docs: https://docs.godotengine.org/
- GDQuest YouTube channel
- HeartBeast YouTube tutorials

### Game Design

- Game Maker's Toolkit (YouTube)
- Extra Credits (YouTube)

### General Programming

- FreeCodeCamp
- Codecademy (free tier)

## Development Workflow

1. **Start Small**: Build a combat prototype first
2. **Iterate**: Test each system before moving on
3. **Document**: Keep design docs updated
4. **Version Control**: Commit frequently
5. **Test Early**: Playtest with friends as soon as possible

## Budget Breakdown (FREE Route)

- ✅ Game Engine: Godot (Free)
- ✅ 2D Art: Aseprite (Paid, but you have license) or GIMP (Free)
- ✅ Code Editor: VS Code (Free)
- ✅ Version Control: Git/GitHub (Free)
- ✅ Audio Tools: Audacity (Free)
- ✅ Assets: Free resources online
- ✅ Hosting: GitHub (Free)

**Total Cost: $0** (assuming you do the work yourself, or use free alternatives)

## Next Steps

1. **Download Godot** and follow a basic tutorial
2. **Create a simple combat prototype** (2 characters, turn-based)
3. **Learn the basics** of your chosen engine
4. **Build incrementally** - don't try to build everything at once

## Important Notes

- **Scope Management**: This is a large project. Consider starting with single-player first, then adding multiplayer later.
- **Team**: If possible, find collaborators (artist, programmer, designer)
- **Time**: Expect this to take 1-2 years for a solo developer
- **MVP First**: Build a Minimum Viable Product (playable demo) before full features

## Questions to Consider

1. **Solo or Team?** - Multiplayer games are complex; consider finding teammates
2. **2D Pixel Art** - Using Aseprite for sprites and animations
3. **Single-player First?** - Build core systems without multiplayer, add it later
4. **Art Style**: Pixel art is great for solo devs (faster to create, classic aesthetic)

---

**Recommendation**: Start with **Godot Engine**, build a **2D pixel art prototype** to test your ATB system. 2D is perfect for a first-time game project and allows you to focus on gameplay mechanics.
