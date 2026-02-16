# SwiftData Integration - Todoist Dashboard

## 📋 Огляд

Додаток тепер використовує **SwiftData** для локального збереження всіх даних з Todoist API. Це забезпечує:

- ✅ **Офлайн-режим** - перегляд даних без інтернету
- ⚡ **Швидке завантаження** - миттєвий доступ до кешованих даних
- 🔄 **Автоматична синхронізація** - оновлення даних з API
- 💾 **Персистентність** - дані зберігаються між запусками

## 🏗️ Архітектура

### Структура файлів:

```
SwiftDataModels.swift       - SwiftData моделі (@Model класи)
DataSyncService.swift       - Сервіс для роботи з SwiftData
AppState.swift              - Оновлений для використання SwiftData
TodoistDashboardApp.swift   - Ініціалізація ModelContainer
KeychainService.swift       - Збереження токена та userId
```

### Моделі SwiftData:

1. **SDUser** - Користувач Todoist
2. **SDProject** - Проекти
3. **SDTask** - Активні задачі
4. **SDSection** - Секції проектів
5. **SDCollaborator** - Співробітники
6. **SDCompletedTask** - Завершені задачі
7. **SDActivityEvent** - Події активності
8. **SDUserStats** - Статистика користувача

Кожна модель має:
- `@Attribute(.unique) var id` - унікальний ідентифікатор
- `var lastSynced: Date` - дата останньої синхронізації
- `toXXX()` - конвертація в API модель
- `static func from()` - створення з API моделі

### Relationships:

```swift
SDProject -> [SDTask]      (one-to-many)
SDProject -> [SDSection]   (one-to-many)
```

## 🔄 Процес синхронізації

### 1. Ініціалізація додатка

```swift
// TodoistDashboardApp.swift
init() {
    // Створюємо ModelContainer
    modelContainer = try ModelContainer(for: schema)
    
    // Створюємо DataSyncService
    dataSyncService = DataSyncService(modelContainer: modelContainer)
    
    // Ініціалізуємо AppState з DataSyncService
    _appState = StateObject(wrappedValue: AppState(dataSyncService: dataSyncService))
}
```

### 2. Завантаження кешованих даних

```swift
// AppState.swift - init()
if let token = KeychainService.getToken() {
    isAuthenticated = true
    loadCachedData() // 📂 Завантажуємо дані з SwiftData
}
```

### 3. Синхронізація з API

```swift
// AppState.swift - performFullSync()
async {
    // 1. Отримуємо дані з API
    let projects = try await client.fetchAll(endpoint: "/projects")
    
    // 2. Оновлюємо @Published властивість (UI)
    self.projects = projects
    
    // 3. Зберігаємо в SwiftData
    try? syncService.saveProjects(projects)
}
```

### 4. Схема роботи

```
Запуск додатка
    ↓
Є токен? → Ні → AuthView
    ↓ Так
Завантаження з SwiftData (миттєво)
    ↓
Відображення UI з кешованими даними
    ↓
performFullSync() - фонова синхронізація
    ↓
Оновлення UI з новими даними
    ↓
Збереження в SwiftData
```

## 📊 DataSyncService API

### Збереження даних

```swift
// Projects
try syncService.saveProjects([TodoistProject])
let projects = syncService.fetchProjects() -> [TodoistProject]

// Tasks
try syncService.saveTasks([TodoistTask])
let tasks = syncService.fetchTasks() -> [TodoistTask]

// Collaborators
try syncService.saveCollaborators([String: [Collaborator]])
let collaborators = syncService.fetchCollaborators() -> [String: [Collaborator]]

// Completed Tasks
try syncService.saveCompletedTasks([CompletedTask])
let completed = syncService.fetchCompletedTasks() -> [CompletedTask]
```

### Утилітарні методи

```swift
// Очистити всі дані
try syncService.clearAllData()

// Отримати дату останньої синхронізації
let lastSync = syncService.getLastSyncDate()
```

## 🎯 Переваги реалізації

### 1. Миттєве завантаження

При запуску додатка дані завантажуються з локальної бази (SwiftData) миттєво, навіть без інтернету.

### 2. Оптимістичне оновлення

UI оновлюється спочатку з кешу, потім фоново синхронізується з API.

### 3. Offline-First підхід

- Дані завжди доступні локально
- Синхронізація відбувається в фоні
- Користувач може переглядати дані офлайн

### 4. Автоматичне управління пам'яттю

SwiftData автоматично:
- Видаляє застарілі записи
- Оновлює існуючі
- Керує relationships між моделями

### 5. Type-Safe queries

```swift
// SwiftData використовує type-safe предикати
let descriptor = FetchDescriptor<SDTask>(
    predicate: #Predicate { $0.isCompleted == false },
    sortBy: [SortDescriptor(\.priority, order: .reverse)]
)
```

## 🔐 Безпека

- **Токен API** зберігається в Keychain
- **User ID** зберігається в Keychain
- **Дані** зберігаються локально через SwiftData
- **CloudKit** відключений (`cloudKitDatabase: .none`)

## 📱 Використання

### Pull-to-Refresh

Всі екрани підтримують `refreshable`:

```swift
.refreshable {
    await appState.performFullSync()
}
```

### Індикатор синхронізації

```swift
switch appState.syncState {
case .idle: // Не синхронізовано
case .syncing: // Синхронізація...
case .synced(let date): // Синхронізовано [дата]
case .error(let message): // Помилка
}
```

## 🐛 Debug режим

В DEBUG режимі додано логування:

```swift
#if DEBUG
print("💾 Saved 10 projects to SwiftData")
print("📂 Loaded: 10 projects, 25 tasks, 15 completed")
print("✅ Full sync completed and saved to SwiftData")
#endif
```

## 📈 Статистика

Всі обчислення статистики працюють з даними з `@Published` властивостей AppState, які автоматично оновлюються після синхронізації.

```swift
func statistics(for userId: String) -> MemberStatistics {
    let memberTasks = tasks(assignedTo: userId) // З @Published tasks
    let completed = completedTasks(assignedTo: userId)
    // ... обчислення
}
```

## 🚀 Майбутні покращення

- [ ] Інкрементальна синхронізація (тільки зміни)
- [ ] Конфлікт-резолюшн при офлайн змінах
- [ ] Background refresh
- [ ] Автоматична синхронізація за таймером
- [ ] Sync tokens для delta sync
- [ ] iCloud sync (опціонально)
- [ ] Compression кешованих даних

## 📝 Примітки

1. **Видалення задач**: Якщо задача видалена з API, вона автоматично видаляється з SwiftData
2. **Старі completed tasks**: Задачі старші 3 місяців автоматично видаляються
3. **Relationships**: SwiftData автоматично підтримує зв'язки між проектами та задачами
4. **Migration**: При зміні схеми SwiftData автоматично виконує міграцію

## ⚠️ Важливо

- Всі операції з SwiftData виконуються на `@MainActor`
- `modelContext.autosaveEnabled = true` для автоматичного збереження
- При logout очищаються всі дані з SwiftData
- UserId зберігається в Keychain для швидкого доступу до user data
