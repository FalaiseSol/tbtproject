# MVP Implementation Plan - First Version

## Goal
Build a working prototype where players can:
1. ✅ Register and login
2. ✅ Connect/disconnect
3. ✅ Create a new character
4. ✅ Spawn in a square room
5. ✅ Move the character around

---

## Tech Stack (All Free)

### Option 1: Firebase (Recommended - No Backend Server!) ⭐

#### Frontend (Game Client)
- **Engine**: Godot Engine (Standard)
- **Language**: GDScript
- **Firebase SDK**: Godot Firebase plugin
  - **Link**: https://github.com/GodotNuts/GodotFirebase
  - **Installation**: Add as Godot plugin
- **Networking**: Firebase SDK handles all networking

#### Backend
- **None needed!** Firebase handles everything:
  - Authentication (Firebase Auth)
  - Database (Firestore)
  - Real-time updates (Firestore listeners)

#### Database
- **Development**: Firebase Emulator (local testing)
- **Production**: Firebase (free tier)

---

### Option 2: PostgreSQL + Backend Server (Traditional)

#### Frontend (Game Client)
- **Engine**: Godot Engine (Standard)
- **Language**: GDScript
- **Networking**: HTTPRequest (for API calls), WebSocket (for real-time, future)

#### Backend (Server)
- **Runtime**: Node.js (or Python)
- **Framework**: Express.js (or FastAPI)
- **Database**: PostgreSQL (Supabase free tier)
- **Authentication**: JWT tokens

#### Database
- **Development**: SQLite (local) or PostgreSQL (Supabase)
- **Production**: PostgreSQL (Supabase)

---

## Step-by-Step Implementation (Firebase Version) ⭐

### Phase 1: Firebase Setup (Day 1)

#### 1.1 Set Up Firebase Project
- [ ] Create Firebase account at https://firebase.google.com/
- [ ] Create new project
- [ ] Enable Authentication (Email/Password)
- [ ] Enable Firestore Database
- [ ] Get Firebase config (API keys)
- [ ] Set up Firestore security rules (see `DATABASE_DESIGN.md`)

#### 1.2 Install Firebase in Godot
- [ ] Download Godot Firebase plugin: https://github.com/GodotNuts/GodotFirebase
- [ ] Add plugin to Godot project
- [ ] Configure Firebase config file
- [ ] Test Firebase connection

---

### Phase 2: Godot Client - Authentication (Days 2-3)

#### 2.1 Create Project Structure
```
tbtproject/
├── scenes/
│   ├── Main.tscn (main menu)
│   ├── Login.tscn
│   ├── Register.tscn
│   ├── CharacterSelect.tscn
│   ├── CharacterCreate.tscn
│   └── Game.tscn (game world)
├── scripts/
│   ├── firebase/
│   │   ├── firebase_manager.gd (Firebase initialization)
│   │   └── auth_manager.gd (Firebase Auth)
│   ├── ui/
│   │   ├── login_ui.gd
│   │   └── register_ui.gd
│   └── game/
│       └── player.gd
└── assets/
    └── models/
```

#### 2.2 Implement Firebase Auth
- [ ] Create `firebase_manager.gd` - Initialize Firebase
- [ ] Create `auth_manager.gd` - Handle registration/login
- [ ] Register user: `Firebase.Auth.register_with_email_and_password(email, password)`
- [ ] Login user: `Firebase.Auth.login_with_email_and_password(email, password)`
- [ ] Store auth state in user preferences

#### 2.3 Create UI Scenes
- [ ] Main menu scene
- [ ] Login scene (email/password fields)
- [ ] Register scene (email/password fields)
- [ ] Connect UI to Firebase Auth

---

### Phase 3: Character System (Days 4-5)

#### 3.1 Character Selection Screen
- [ ] Create character list UI
- [ ] Load characters from Firestore: `Firebase.Firestore.collection("characters").where("userId", "==", user_id).get()`
- [ ] Display character names
- [ ] "Create New" button

#### 3.2 Character Creation
- [ ] Character creation form (name input)
- [ ] Create character document in Firestore:
  ```gdscript
  var character_data = {
    "userId": user_id,
    "name": character_name,
    "position": {"x": 0, "y": 0, "z": 0, "roomId": "spawn_room_1"},
    "stats": {...default stats...},
    "isOnline": false
  }
  Firebase.Firestore.collection("characters").add(character_data)
  ```
- [ ] Redirect to game after creation

#### 3.3 Character Data Loading
- [ ] Load character data on game start
- [ ] Store character ID and stats
- [ ] Initialize character with default appearance

---

### Phase 4: Game World - Room & Movement (Days 6-8)

#### 4.1 Create Square Room
- [ ] Create 2D scene with floor (ColorRect or TileMap)
- [ ] Add walls (4 walls around the square using StaticBody2D)
- [ ] Set up Camera2D
- [ ] Use pixel art tileset for room visuals (optional)

#### 4.2 Character Sprite
- [ ] Create or import pixel art character sprite
- [ ] Create character scene with Sprite2D
- [ ] Add CharacterBody2D with movement script

#### 4.3 Movement System with Real-Time Updates
- [ ] Implement WASD/arrow key movement
- [ ] Smooth character movement
- [ ] Update position in Firestore (every 0.5 seconds):
  ```gdscript
  Firebase.Firestore.collection("characters").document(character_id).update({
    "position": {"x": pos.x, "y": pos.y}
  })
  ```
- [ ] **Real-time listener**: Watch for other players' positions:
  ```gdscript
  Firebase.Firestore.collection("characters").where("roomId", "==", current_room).on_snapshot(func(snapshot):
    # Update other players' positions in real-time!
    for doc in snapshot.documents:
      update_other_player(doc.id, doc.data.position)
  )
  ```

#### 4.4 Spawn System
- [ ] Load character position from Firestore
- [ ] Spawn character at saved position (or default spawn point)
- [ ] Handle first-time spawn (center of room)

---

### Phase 5: Connection Management (Days 9-10)

#### 5.1 Session Management
- [ ] Create session document on game start
- [ ] Update `isOnline = true` in character document
- [ ] Handle disconnect (close game, network error)
- [ ] Update `isOnline = false` on disconnect

#### 5.2 Real-Time Multiplayer
- [ ] Listen to all characters in current room
- [ ] Spawn other players when they join
- [ ] Update other players' positions in real-time
- [ ] Remove players when they disconnect

---

### Phase 6: Testing & Polish (Days 11-14)

#### 6.1 Testing
- [ ] Test user registration
- [ ] Test login/logout
- [ ] Test character creation
- [ ] Test movement and position saving
- [ ] Test real-time multiplayer (open 2 clients)
- [ ] Test disconnect/reconnect

#### 6.2 Bug Fixes & Polish
- [ ] Fix any movement issues
- [ ] Fix Firebase connection issues
- [ ] Fix UI bugs
- [ ] Optimize position update frequency
- [ ] Add loading screens
- [ ] Add error messages

---

## Step-by-Step Implementation (PostgreSQL + Backend Version)

### Phase 1: Backend Setup (Days 1-2)

#### 1.1 Set Up Database
- [ ] Create Supabase account (or install PostgreSQL locally)
- [ ] Create database schema (see `DATABASE_DESIGN.md`)
- [ ] Run SQL scripts to create tables

#### 1.2 Set Up Backend Server
- [ ] Initialize Node.js project
- [ ] Install dependencies: `express`, `pg`, `bcrypt`, `jsonwebtoken`, `cors`
- [ ] Create basic Express server
- [ ] Set up database connection

#### 1.3 Create API Endpoints
- [ ] `POST /api/auth/register` - User registration
- [ ] `POST /api/auth/login` - User login
- [ ] `POST /api/auth/logout` - User logout
- [ ] `GET /api/characters` - List user's characters
- [ ] `POST /api/characters` - Create new character
- [ ] `GET /api/characters/:id` - Get character data
- [ ] `PUT /api/characters/:id/position` - Update character position
- [ ] `POST /api/sessions/connect` - Connect to game
- [ ] `POST /api/sessions/disconnect` - Disconnect from game

---

### Phase 2: Godot Client - Authentication (Days 3-4)

#### 2.1 Create Project Structure
```
tbtproject/
├── scenes/
│   ├── Main.tscn (main menu)
│   ├── Login.tscn
│   ├── Register.tscn
│   ├── CharacterSelect.tscn
│   ├── CharacterCreate.tscn
│   └── Game.tscn (game world)
├── scripts/
│   ├── api/
│   │   ├── api_client.gd (HTTP requests)
│   │   └── auth_manager.gd (authentication)
│   ├── ui/
│   │   ├── login_ui.gd
│   │   └── register_ui.gd
│   └── game/
│       └── player.gd
└── assets/
    └── models/
```

#### 2.2 Implement API Client
- [ ] Create `api_client.gd` - HTTP request handler
- [ ] Create `auth_manager.gd` - Authentication logic
- [ ] Store JWT token in user preferences

#### 2.3 Create UI Scenes
- [ ] Main menu scene
- [ ] Login scene (username/password fields)
- [ ] Register scene (username/email/password)
- [ ] Connect UI to API endpoints

---

### Phase 3: Character System (Days 5-6)

#### 3.1 Character Selection Screen
- [ ] Create character list UI
- [ ] Load characters from API
- [ ] Display character names
- [ ] "Create New" button

#### 3.2 Character Creation
- [ ] Character creation form (name input)
- [ ] Send creation request to API
- [ ] Create default character stats
- [ ] Redirect to game after creation

#### 3.3 Character Data Loading
- [ ] Load character data on game start
- [ ] Store character ID and stats
- [ ] Initialize character with default appearance

---

### Phase 4: Game World - Room & Movement (Days 7-9)

#### 4.1 Create Square Room
- [ ] Create 2D scene with floor (ColorRect or TileMap)
- [ ] Add walls (4 walls around the square using StaticBody2D)
- [ ] Set up Camera2D
- [ ] Use pixel art tileset for room visuals (optional)

#### 4.2 Character Sprite
- [ ] Create or import pixel art character sprite
  - **Free Asset Sources**:
    - OpenGameArt.org (pixel art sprites)
    - Itch.io (free pixel art assets)
    - Kenney.nl (free 2D characters)
- [ ] Create character scene with Sprite2D
- [ ] Add CharacterBody2D with movement script

#### 4.3 Movement System
- [ ] Implement WASD/arrow key movement
- [ ] Smooth character movement
- [ ] Update position in database (every 0.5 seconds or on change)
- [ ] Send position updates to API (x, y coordinates only)

#### 4.4 Spawn System
- [ ] Load character position from database
- [ ] Spawn character at saved position (or default spawn point)
- [ ] Handle first-time spawn (center of room)

---

### Phase 5: Connection Management (Days 10-11)

#### 5.1 Session Management
- [ ] Create session on game start
- [ ] Send heartbeat every 30 seconds
- [ ] Handle disconnect (close game, network error)
- [ ] Update `is_online` status in database

#### 5.2 Reconnection Logic
- [ ] Detect connection loss
- [ ] Show "Reconnecting..." message
- [ ] Attempt to reconnect
- [ ] Restore character state on reconnect

---

### Phase 6: Testing & Polish (Days 12-14)

#### 6.1 Testing
- [ ] Test user registration
- [ ] Test login/logout
- [ ] Test character creation
- [ ] Test movement and position saving
- [ ] Test disconnect/reconnect
- [ ] Test with multiple users (if possible)

#### 6.2 Bug Fixes
- [ ] Fix any movement issues
- [ ] Fix API connection issues
- [ ] Fix UI bugs
- [ ] Optimize position update frequency

#### 6.3 Polish
- [ ] Add loading screens
- [ ] Add error messages
- [ ] Improve UI appearance
- [ ] Add basic animations

---

## File Structure Example

### Backend (Node.js)
```
backend/
├── server.js
├── routes/
│   ├── auth.js
│   ├── characters.js
│   └── sessions.js
├── models/
│   ├── user.js
│   ├── character.js
│   └── session.js
├── middleware/
│   └── auth.js (JWT verification)
└── config/
    └── database.js
```

### Frontend (Godot)
```
godot_project/
├── project.godot
├── scenes/
│   ├── Main.tscn
│   ├── Login.tscn
│   ├── Register.tscn
│   ├── CharacterSelect.tscn
│   ├── CharacterCreate.tscn
│   └── Game.tscn
├── scripts/
│   ├── api/
│   │   ├── api_client.gd
│   │   └── auth_manager.gd
│   ├── ui/
│   │   ├── main_menu.gd
│   │   ├── login_ui.gd
│   │   ├── register_ui.gd
│   │   ├── character_select.gd
│   │   └── character_create.gd
│   └── game/
│       ├── game_manager.gd
│       ├── player.gd
│       └── room.gd
└── assets/
    └── sprites/
        └── character_default.png
```

---

## API Endpoint Specifications

### Authentication

#### `POST /api/auth/register`
```json
Request:
{
  "username": "player1",
  "email": "player1@example.com",
  "password": "securepassword123"
}

Response:
{
  "success": true,
  "message": "User registered successfully",
  "token": "jwt_token_here"
}
```

#### `POST /api/auth/login`
```json
Request:
{
  "username": "player1",
  "password": "securepassword123"
}

Response:
{
  "success": true,
  "token": "jwt_token_here",
  "user": {
    "id": 1,
    "username": "player1"
  }
}
```

### Characters

#### `GET /api/characters`
```json
Headers: Authorization: Bearer {token}

Response:
{
  "success": true,
  "characters": [
    {
      "id": 1,
      "name": "MyCharacter",
      "created_at": "2024-01-01T00:00:00Z",
      "last_played": "2024-01-01T12:00:00Z"
    }
  ]
}
```

#### `POST /api/characters`
```json
Request:
{
  "name": "MyNewCharacter"
}

Response:
{
  "success": true,
  "character": {
    "id": 2,
    "name": "MyNewCharacter",
    "position_x": 0.0,
    "position_y": 0.0
  }
}
```

#### `PUT /api/characters/:id/position`
```json
Request:
{
  "position_x": 5.2,
  "position_y": 0.0
}

Response:
{
  "success": true
}
```

### Sessions

#### `POST /api/sessions/connect`
```json
Request:
{
  "character_id": 1
}

Response:
{
  "success": true,
  "session_id": "session_uuid_here"
}
```

#### `POST /api/sessions/disconnect`
```json
Request:
{
  "session_id": "session_uuid_here"
}

Response:
{
  "success": true
}
```

---

## Free Character Asset Recommendations

### For MVP (Default Pixel Art Character)
1. **OpenGameArt.org** - Free pixel art sprites
   - Link: https://opengameart.org/
   - Search: "pixel art character" or "RPG sprite"
   - Many free options with various licenses

2. **Itch.io** - Free pixel art assets
   - Link: https://itch.io/game-assets/free
   - Search: "pixel art character" or "2D sprite"
   - Many free assets with CC0 license

3. **Kenney.nl** - Free 2D character packs
   - Link: https://kenney.nl/assets
   - Search: "Character" or "2D"
   - Format: PNG spritesheets (works in Godot)

4. **Craftpix.net** - Free pixel art packs
   - Link: https://craftpix.net/freebies/
   - Free pixel art character sprites
   - Various styles available

---

## Development Tips

### 1. Start Simple
- Use a simple colored rectangle (ColorRect) for character initially
- Focus on functionality over graphics
- Add pixel art sprites later

### 2. Test Incrementally
- Test each feature as you build it
- Don't wait until the end to test
- Use print statements for debugging

### 3. Version Control
- Commit frequently
- Use descriptive commit messages
- Keep backend and frontend in separate repos (or monorepo)

### 4. API Testing
- Use Postman or Insomnia to test API endpoints
- Test before integrating with Godot
- Verify database changes

### 5. Error Handling
- Always handle network errors
- Show user-friendly error messages
- Log errors for debugging

---

## Next Steps After MVP

Once MVP is complete, you can add:
1. Multiple rooms/areas
2. Other players visible in the same room
3. Character customization (appearance)
4. Basic inventory system
5. Equipment system
6. Combat system (ATB)
7. Procedural generation

---

## Estimated Timeline

- **Backend Setup**: 2 days
- **Frontend Auth**: 2 days
- **Character System**: 2 days
- **Game World**: 3 days
- **Connection Management**: 2 days
- **Testing & Polish**: 3 days

**Total: ~2 weeks** (working part-time) or **~1 week** (full-time)

---

## Questions?

If you get stuck:
1. Check Godot documentation
2. Check your chosen backend framework docs
3. Test API endpoints independently
4. Use print statements for debugging
5. Ask for help (me or community forums)

Good luck! 🚀

