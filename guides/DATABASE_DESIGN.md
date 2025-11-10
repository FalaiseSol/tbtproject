# Database Design - TBT Project

## Database Solution Recommendation

### **Firebase (Firestore)** ⭐ **RECOMMENDED FOR MULTIPLAYER**
- **Why**: Real-time database, built-in auth, perfect for games
- **Pros**:
  - ✅ **Real-time updates** - Perfect for multiplayer (players see each other move instantly)
  - ✅ **Built-in authentication** - No need to build auth system
  - ✅ **Free tier** - Generous free quota (50K reads/day, 20K writes/day)
  - ✅ **Easy setup** - No server needed, works directly from Godot
  - ✅ **Offline support** - Works offline, syncs when online
  - ✅ **Scalable** - Handles millions of users
  - ✅ **NoSQL flexibility** - Easy to store complex data (JSON-like)
  - ✅ **Security rules** - Built-in security for data access
- **Cons**:
  - ❌ NoSQL (less structured queries than SQL)
  - ❌ Can get expensive at very large scale (but free tier is generous)
  - ❌ Different data modeling approach
- **Best for**: Real-time multiplayer games, rapid prototyping
- **Link**: https://firebase.google.com/

### **PostgreSQL** (Alternative - Traditional SQL)
- **Why**: Free, open-source, industry standard
- **Pros**:
  - ✅ Excellent for relational data (users, characters, equipment)
  - ✅ ACID compliant (data integrity)
  - ✅ Great for complex queries and joins
  - ✅ JSON support (for flexible data like skill trees)
  - ✅ Free hosting options (Supabase, Railway, Render)
  - ✅ Scales well
- **Cons**:
  - ❌ Requires backend server (can't connect directly from Godot)
  - ❌ No built-in real-time updates (need WebSockets)
  - ❌ More setup required
- **Download**: https://www.postgresql.org/download/

### **SQLite** (For Development/Offline Mode)
- **Why**: File-based, no server needed
- **Pros**: 
  - ✅ Perfect for single-player offline mode
  - ✅ No setup required
  - ✅ Can migrate to PostgreSQL later
- **Cons**: Not ideal for multiplayer (but fine for local testing)

### **Architecture Strategy Comparison**

#### **Option 1: Firebase (Recommended for Your Use Case)**
- **Development**: Firebase (free tier, easy testing)
- **Production**: Firebase (same database, scales automatically)
- **Pros**: Real-time multiplayer out of the box, no backend server needed
- **Best for**: Games that need real-time updates (like yours!)

#### **Option 2: PostgreSQL**
- **Development**: SQLite (local file, easy testing)
- **Production**: PostgreSQL (hosted, multiplayer-ready)
- **Migration**: Easy to migrate from SQLite → PostgreSQL
- **Pros**: Traditional SQL, more control, better for complex queries
- **Cons**: Need backend API server, need WebSockets for real-time

---

## Database Schema Design

### Core Tables (MVP - First Version)

#### 1. `users` - User Accounts
```sql
CREATE TABLE users (
    id SERIAL PRIMARY KEY,
    username VARCHAR(50) UNIQUE NOT NULL,
    email VARCHAR(255) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,  -- bcrypt hash
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    last_login TIMESTAMP,
    is_active BOOLEAN DEFAULT TRUE
);

CREATE INDEX idx_users_username ON users(username);
CREATE INDEX idx_users_email ON users(email);
```

**Purpose**: Store user account information for registration/login

---

#### 2. `characters` - Character Data
```sql
CREATE TABLE characters (
    id SERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    name VARCHAR(50) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    last_played TIMESTAMP,
    
    -- Character Appearance (for future customization)
    appearance_data JSONB,  -- {posture, corpulence, hair, facial_hair, skin_color}
    
    -- Current Location
    current_room_id INTEGER,  -- References rooms table (for future)
    position_x FLOAT DEFAULT 0.0,
    position_y FLOAT DEFAULT 0.0,
    
    -- Character State
    is_online BOOLEAN DEFAULT FALSE,
    current_session_id VARCHAR(255),  -- For tracking active sessions
    
    CONSTRAINT unique_user_character_name UNIQUE(user_id, name)
);

CREATE INDEX idx_characters_user_id ON characters(user_id);
CREATE INDEX idx_characters_online ON characters(is_online);
```

**Purpose**: Store character data, position, and online status

---

#### 3. `character_stats` - Character Attributes & Stats
```sql
CREATE TABLE character_stats (
    character_id INTEGER PRIMARY KEY REFERENCES characters(id) ON DELETE CASCADE,
    
    -- Primary Stats
    hp_current INTEGER DEFAULT 100,
    hp_max INTEGER DEFAULT 100,
    mana_current INTEGER DEFAULT 50,
    mana_max INTEGER DEFAULT 50,
    stamina_current INTEGER DEFAULT 100,
    stamina_max INTEGER DEFAULT 100,
    
    -- Attributes
    strength INTEGER DEFAULT 10,
    agility INTEGER DEFAULT 10,
    intelligence INTEGER DEFAULT 10,
    spirit INTEGER DEFAULT 10,
    defense INTEGER DEFAULT 10,
    luck INTEGER DEFAULT 10,
    speed INTEGER DEFAULT 10,
    
    -- Derived Stats (calculated, but cached for performance)
    crit_chance FLOAT DEFAULT 0.05,
    evasion FLOAT DEFAULT 0.05,
    spell_power FLOAT DEFAULT 1.0,
    cooldown_reduction FLOAT DEFAULT 0.0,
    hp_regen FLOAT DEFAULT 1.0,
    mana_regen FLOAT DEFAULT 1.0,
    
    -- Progression
    level INTEGER DEFAULT 1,
    experience INTEGER DEFAULT 0,
    experience_to_next INTEGER DEFAULT 100,
    
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

**Purpose**: Store all character stats and attributes (from your game design)

---

#### 4. `sessions` - Active Game Sessions
```sql
CREATE TABLE sessions (
    id VARCHAR(255) PRIMARY KEY,  -- UUID or session token
    user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    character_id INTEGER REFERENCES characters(id) ON DELETE SET NULL,
    ip_address VARCHAR(45),  -- IPv6 compatible
    connected_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    last_activity TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    is_active BOOLEAN DEFAULT TRUE
);

CREATE INDEX idx_sessions_user_id ON sessions(user_id);
CREATE INDEX idx_sessions_character_id ON sessions(character_id);
CREATE INDEX idx_sessions_active ON sessions(is_active);
```

**Purpose**: Track active connections, handle disconnect/reconnect

---

### Future Tables (For Later Development)

#### 5. `equipment` - Character Equipment
```sql
CREATE TABLE equipment (
    id SERIAL PRIMARY KEY,
    character_id INTEGER NOT NULL REFERENCES characters(id) ON DELETE CASCADE,
    slot VARCHAR(20) NOT NULL,  -- 'head', 'chest', 'main_hand', etc.
    item_id INTEGER,  -- References items table (future)
    item_data JSONB,  -- Store item stats, rarity, affixes
    equipped_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    CONSTRAINT unique_character_slot UNIQUE(character_id, slot)
);

CREATE INDEX idx_equipment_character_id ON equipment(character_id);
```

**Purpose**: Store equipped items (all 11 slots from your design)

---

#### 6. `inventory` - Character Inventory
```sql
CREATE TABLE inventory (
    id SERIAL PRIMARY KEY,
    character_id INTEGER NOT NULL REFERENCES characters(id) ON DELETE CASCADE,
    item_id INTEGER,  -- References items table
    item_data JSONB,  -- Item stats, rarity, etc.
    quantity INTEGER DEFAULT 1,
    slot_position INTEGER,  -- Inventory slot number
    obtained_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_inventory_character_id ON inventory(character_id);
```

**Purpose**: Store items in character inventory

---

#### 7. `character_skills` - Learned Skills & Magic
```sql
CREATE TABLE character_skills (
    id SERIAL PRIMARY KEY,
    character_id INTEGER NOT NULL REFERENCES characters(id) ON DELETE CASCADE,
    skill_id INTEGER,  -- References skills table (future)
    skill_name VARCHAR(100) NOT NULL,
    skill_type VARCHAR(20),  -- 'active', 'passive', 'magic'
    skill_data JSONB,  -- Skill properties, cooldowns, etc.
    learned_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    level INTEGER DEFAULT 1
);

CREATE INDEX idx_character_skills_character_id ON character_skills(character_id);
```

**Purpose**: Store learned skills and magic from skill trees

---

#### 8. `rooms` - Game Rooms/Areas (Future)
```sql
CREATE TABLE rooms (
    id SERIAL PRIMARY KEY,
    room_type VARCHAR(50),  -- 'spawn', 'city', 'dungeon', 'overworld'
    room_name VARCHAR(100),
    room_data JSONB,  -- Procedural generation seed, layout, etc.
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

**Purpose**: Store room/area data for multiplayer instances

---

## Firebase (Firestore) Schema Design

Firestore uses a NoSQL document-based structure. Here's how your data would be organized:

### Collections Structure

```
firestore/
├── users/                    # User accounts (Firebase Auth handles this)
│   └── {userId}/
│       ├── username: string
│       ├── email: string
│       ├── createdAt: timestamp
│       └── lastLogin: timestamp
│
├── characters/               # Character data
│   └── {characterId}/
│       ├── userId: string (reference)
│       ├── name: string
│       ├── createdAt: timestamp
│       ├── lastPlayed: timestamp
│       ├── appearance: map {
│       │     posture: string,
│       │     corpulence: string,
│       │     hair: string,
│       │     facialHair: string,
│       │     skinColor: string
│       │   }
│       ├── position: map {
│       │     x: float,
│       │     y: float,
│       │     z: float,
│       │     roomId: string
│       │   }
│       ├── isOnline: boolean
│       ├── currentSessionId: string
│       └── stats: map {
│             hpCurrent: int,
│             hpMax: int,
│             manaCurrent: int,
│             manaMax: int,
│             staminaCurrent: int,
│             staminaMax: int,
│             strength: int,
│             agility: int,
│             intelligence: int,
│             spirit: int,
│             defense: int,
│             luck: int,
│             speed: int,
│             level: int,
│             experience: int
│           }
│
├── sessions/                 # Active game sessions
│   └── {sessionId}/
│       ├── userId: string
│       ├── characterId: string
│       ├── ipAddress: string
│       ├── connectedAt: timestamp
│       ├── lastActivity: timestamp
│       └── isActive: boolean
│
├── rooms/                    # Game rooms/areas (future)
│   └── {roomId}/
│       ├── roomType: string
│       ├── roomName: string
│       ├── roomData: map
│       └── players: array [characterId1, characterId2, ...]
│
└── equipment/                # Character equipment (future)
    └── {characterId}/
        ├── head: map {...}
        ├── chest: map {...}
        ├── mainHand: map {...}
        └── ... (other slots)
```

### Example Firestore Document Structure

#### Character Document
```json
{
  "userId": "user123",
  "name": "MyCharacter",
  "createdAt": "2024-01-01T00:00:00Z",
  "lastPlayed": "2024-01-01T12:00:00Z",
  "appearance": {
    "posture": "normal",
    "corpulence": "average",
    "hair": "short",
    "facialHair": "none",
    "skinColor": "fair"
  },
      "position": {
        "x": 5.2,
        "y": 0.0,
        "roomId": "spawn_room_1"
      },
  "isOnline": true,
  "currentSessionId": "session_abc123",
  "stats": {
    "hpCurrent": 100,
    "hpMax": 100,
    "manaCurrent": 50,
    "manaMax": 50,
    "strength": 10,
    "agility": 10,
    "intelligence": 10,
    "level": 1,
    "experience": 0
  }
}
```

### Firebase Real-Time Listeners (Key Advantage!)

With Firebase, you can listen to real-time updates directly in Godot:

```gdscript
# Listen to character position changes in real-time
func watch_character_position(character_id: String):
    var character_ref = Firebase.Firestore.collection("characters").document(character_id)
    character_ref.on_snapshot(func(snapshot):
        var position = snapshot.data.position
        # Update other players' positions instantly!
        update_other_player_position(character_id, position)
    )

# Listen to all players in a room
func watch_room_players(room_id: String):
    var room_ref = Firebase.Firestore.collection("rooms").document(room_id)
    room_ref.collection("players").on_snapshot(func(snapshot):
        # See players join/leave in real-time!
        update_player_list(snapshot.documents)
    )
```

### Firebase Security Rules Example

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Users can only read/write their own user document
    match /users/{userId} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }
    
    // Users can read/write their own characters
    match /characters/{characterId} {
      allow read: if request.auth != null;
      allow write: if request.auth != null && 
                      resource.data.userId == request.auth.uid;
    }
    
    // Sessions are readable by owner, writable by owner
    match /sessions/{sessionId} {
      allow read, write: if request.auth != null && 
                            resource.data.userId == request.auth.uid;
    }
  }
}
```

### Firebase Advantages for Your Game

1. **Real-Time Multiplayer**: See other players move instantly (no polling needed!)
2. **No Backend Server**: Connect directly from Godot (saves development time)
3. **Built-in Auth**: Firebase Authentication handles registration/login
4. **Offline Support**: Works offline, syncs when online
5. **Easy Scaling**: Handles millions of users automatically

---

## Database Architecture for Multiplayer

### Connection Flow
1. **User Registration/Login** → `users` table
2. **Character Selection/Creation** → `characters` table
3. **Connect to Game** → Create entry in `sessions` table
4. **Update Character Position** → Update `characters.position_*` fields
5. **Disconnect** → Mark session inactive, update `characters.is_online = FALSE`

### Data Synchronization Strategy

#### **Client-Server Model**
- **Client (Godot)**: Sends position updates, actions
- **Server (Backend API)**: Validates, stores in database, broadcasts to other players
- **Database**: Single source of truth

#### **Update Frequency**
- **Position Updates**: Every 0.1-0.5 seconds (or on movement change)
- **Stats Updates**: On change (HP, Mana, etc.)
- **Equipment Updates**: On equip/unequip
- **Session Heartbeat**: Every 30 seconds (keep session alive)

---

## Free Database Hosting Options

### 1. **Firebase (Firestore)** ⭐ **RECOMMENDED FOR MULTIPLAYER**
- **Why**: Real-time database, built-in auth, no backend server needed
- **Free Tier (Spark Plan)**: 
  - 50,000 reads/day
  - 20,000 writes/day
  - 20,000 deletes/day
  - 1 GB storage
  - Built-in authentication (unlimited)
  - Real-time listeners (unlimited)
  - **Perfect for MVP and small multiplayer games!**
- **Link**: https://firebase.google.com/
- **Note**: No backend server needed! Connect directly from Godot

### 2. **Supabase** (PostgreSQL Option)
- **Why**: Free tier, PostgreSQL, built-in auth, real-time features
- **Free Tier**: 
  - 500 MB database
  - 2 GB bandwidth
  - Built-in authentication
  - Real-time subscriptions
- **Link**: https://supabase.com/
- **Note**: Requires backend API server

### 3. **Railway** (PostgreSQL Option)
- **Why**: Easy PostgreSQL hosting
- **Free Tier**: $5 credit/month (usually enough for small projects)
- **Link**: https://railway.app/

### 4. **Render** (PostgreSQL Option)
- **Why**: Free PostgreSQL database
- **Free Tier**: 90-day free trial, then paid
- **Link**: https://render.com/

### 5. **Local Development**
- **Firebase Emulator**: Test Firebase locally (free)
- **PostgreSQL**: Install locally for development
- **SQLite**: For offline single-player mode

---

## Backend Architecture Options

### **Option 1: Firebase (No Backend Server Needed!)** ⭐ **RECOMMENDED**
- **Why**: Connect directly from Godot to Firebase
- **Setup**: 
  - Install Firebase SDK for Godot
  - Configure Firebase project
  - Use Firebase Auth for login
  - Use Firestore for data
- **Pros**: 
  - ✅ No server to maintain
  - ✅ Real-time updates built-in
  - ✅ Built-in authentication
  - ✅ Faster development
- **Cons**: 
  - ❌ Less control over business logic
  - ❌ Need Firebase SDK for Godot

### **Option 2: Node.js + Express** (For PostgreSQL)
- **Why**: Easy to learn, great for game backends
- **Free**: Yes
- **Libraries**: 
  - `pg` (PostgreSQL client)
  - `bcrypt` (password hashing)
  - `jsonwebtoken` (authentication)
  - `express` (web server)
  - `socket.io` (for real-time, if needed)
- **Note**: Requires hosting (Railway, Render, etc.)

### **Option 3: Python + FastAPI** (For PostgreSQL)
- **Why**: Also great, Python is easy
- **Free**: Yes
- **Libraries**:
  - `sqlalchemy` (database ORM)
  - `passlib` (password hashing)
  - `fastapi` (web framework)
  - `websockets` (for real-time, if needed)
- **Note**: Requires hosting (Railway, Render, etc.)

---

## MVP Implementation Plan

### Phase 1: Basic Setup (Week 1)
1. Set up PostgreSQL database (local or Supabase)
2. Create core tables: `users`, `characters`, `character_stats`, `sessions`
3. Set up basic backend API (Node.js or Python)
4. Implement user registration/login endpoints

### Phase 2: Character System (Week 2)
5. Character creation endpoint
6. Character selection/loading
7. Basic character data storage

### Phase 3: Movement & Rooms (Week 3)
8. Room system (simple square room for now)
9. Position storage and updates
10. Character spawn system

### Phase 4: Connection Management (Week 4)
11. Session management (connect/disconnect)
12. Online status tracking
13. Basic multiplayer foundation

---

## Example API Endpoints (MVP)

```
POST   /api/auth/register     - Register new user
POST   /api/auth/login        - Login user
POST   /api/auth/logout       - Logout user

GET    /api/characters        - Get user's characters
POST   /api/characters        - Create new character
GET    /api/characters/:id    - Get character data
PUT    /api/characters/:id    - Update character (position, stats)

POST   /api/sessions/connect  - Connect to game
POST   /api/sessions/disconnect - Disconnect from game
GET    /api/sessions/status   - Get session status
```

---

## Security Considerations

1. **Password Hashing**: Always use bcrypt (never store plain passwords)
2. **Authentication**: JWT tokens for session management
3. **Input Validation**: Validate all user inputs
4. **SQL Injection**: Use parameterized queries (never string concatenation)
5. **Rate Limiting**: Prevent brute force attacks
6. **HTTPS**: Always use HTTPS in production

---

## Migration Path: Single-Player → Multiplayer

### Single-Player Mode
- Use **SQLite** database (local file)
- No server needed
- All data stored locally
- Can play offline

### Multiplayer Mode
- Use **PostgreSQL** database (hosted)
- Requires server/API
- Data synced across players
- Online only

### Hybrid Approach
- Start with SQLite for development
- Same schema for both databases
- Easy migration script to move data
- Game can detect: local DB = single-player, remote API = multiplayer

---

## Next Steps

1. **Choose Database**: PostgreSQL (Supabase) for production, SQLite for dev
2. **Set Up Backend**: Choose Node.js or Python
3. **Create Database Schema**: Use the SQL above
4. **Build API Endpoints**: Start with auth and character creation
5. **Integrate with Godot**: Connect Godot client to backend API

---

## Questions to Consider

1. **Authentication**: Do you want email verification? Password reset?
2. **Character Limits**: How many characters per user?
3. **Data Retention**: Delete characters on user deletion?
4. **Backup Strategy**: How often to backup database?
5. **Scaling**: Plan for sharding if you get many users?

---

**Recommendation**: Start with **Supabase** (free PostgreSQL + auth) and **Node.js backend**. This gives you a solid foundation that scales from MVP to full multiplayer.

