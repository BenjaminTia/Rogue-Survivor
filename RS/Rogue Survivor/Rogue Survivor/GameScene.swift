//
//  GameScene.swift
//  Rogue Survivor
//
//  Created by Benjamin Tia on 14/6/2025.
//

import SpriteKit
import GameplayKit

class GameScene: SKScene, SKPhysicsContactDelegate {
    
    // MARK: - Properties
    private var avatar: SKSpriteNode!
    private var cameraNode: SKCameraNode!
    private var lastTouchLocation: CGPoint?
    private var moveSpeed: CGFloat = 100.0 // pixels per second
    private var backgroundNode: SKNode!
    private var healthBar: SKShapeNode!
    private var lives: Int = 3 {
        didSet {
            updateHealthBar()
        }
    }
    private var isGameOver = false
    private var enemies: [SKSpriteNode] = []
    private let enemyDetectionRadius: CGFloat = 200.0
    private let enemySpeed: CGFloat = 80.0
    private var gameIsPaused = false
    private var pauseButton: SKLabelNode!
    private var pauseText: SKLabelNode!
    private var enemyCounterLabel: SKLabelNode!
    private var lastEnemySpawnTime: TimeInterval = 0
    private let enemySpawnInterval: TimeInterval = 1.67 // Spawn every 1.67 seconds (3x faster than before)
    private var gameTime: TimeInterval = 0
    private var timerLabel: SKLabelNode!
    private var enemiesKilled: Int = 0
    private var enemiesKilledLabel: SKLabelNode!
    private var lastShootTime: TimeInterval = 0
    private let shootCooldown: TimeInterval = 3.0
    private let bulletSpeed: CGFloat = 300.0
    private var lastPowerUpSpawnTime: TimeInterval = 0
    private let powerUpSpawnInterval: TimeInterval = 15.0 // Spawn every 15 seconds
    private let powerUpSpawnChance: Double = 0.3 // 30% chance to spawn
    private var hasRapidFire: Bool = false
    private var rapidFireEndTime: TimeInterval = 0
    private let rapidFireDuration: TimeInterval = 10.0 // Rapid fire lasts 10 seconds
    private let rapidFireCooldown: TimeInterval = 1.0 // Rapid fire shoots every 1 second
    private var shootSound: SKAction!
    private var retryButton: SKLabelNode!
    private var highScore: Int {
        get {
            return UserDefaults.standard.integer(forKey: "highScore")
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "highScore")
        }
    }
    private var highScoreLabel: SKLabelNode!
    
    // Physics categories
    private let avatarCategory: UInt32 = 0x1 << 0
    private let enemyCategory: UInt32 = 0x1 << 1
    private let wallCategory: UInt32 = 0x1 << 2
    private let bulletCategory: UInt32 = 0x1 << 3
    private let powerUpCategory: UInt32 = 0x1 << 4
    
    // MARK: - Scene Setup
    override func didMove(to view: SKView) {
        physicsWorld.contactDelegate = self
        setupBackground()
        setupCamera()
        setupAvatar()
        setupHealthBar()
        setupPhysicsWorld()
        setupEnemyCounter()
        setupPauseButton()
        setupTimer()
        setupKillCounter()
        setupWalls()
        setupSounds()
        spawnEnemies()
        setupUI()
    }
    
    private func setupBackground() {
        // Create a dark background
        backgroundColor = SKColor(red: 0.1, green: 0.1, blue: 0.1, alpha: 1.0)
        
        // Create a container node for all background elements
        backgroundNode = SKNode()
        addChild(backgroundNode)
        
        // Add some cave-like features
        addCaveFeatures()
    }
    
    private func addCaveFeatures() {
        // Add some random rock formations
        let rockCount = 20
        for _ in 0..<rockCount {
            let rock = SKSpriteNode(color: SKColor(red: 0.3, green: 0.3, blue: 0.3, alpha: 1.0),
                                  size: CGSize(width: CGFloat.random(in: 50...200),
                                             height: CGFloat.random(in: 50...200)))
            
            // Random position within a large area
            let x = CGFloat.random(in: -1000...1000)
            let y = CGFloat.random(in: -1000...1000)
            rock.position = CGPoint(x: x, y: y)
            
            // Random rotation
            rock.zRotation = CGFloat.random(in: 0...CGFloat.pi * 2)
            
            // Add some texture to the rocks
            rock.alpha = CGFloat.random(in: 0.7...0.9)
            
            // Add physics body to rocks
            rock.physicsBody = SKPhysicsBody(rectangleOf: rock.size)
            rock.physicsBody?.isDynamic = false
            rock.physicsBody?.friction = 0.2
            rock.physicsBody?.restitution = 0.1
            
            backgroundNode.addChild(rock)
        }
        
        // Add some stalactites and stalagmites
        let formationCount = 15
        for _ in 0..<formationCount {
            let isStalactite = Bool.random()
            let height = CGFloat.random(in: 100...300)
            let width = CGFloat.random(in: 20...40)
            
            let formation = SKSpriteNode(color: SKColor(red: 0.4, green: 0.4, blue: 0.4, alpha: 1.0),
                                       size: CGSize(width: width, height: height))
            
            // Random position
            let x = CGFloat.random(in: -1000...1000)
            let y = CGFloat.random(in: -1000...1000)
            formation.position = CGPoint(x: x, y: y)
            
            // Rotate stalactites upside down
            if isStalactite {
                formation.zRotation = .pi
            }
            
            // Add physics body
            formation.physicsBody = SKPhysicsBody(rectangleOf: formation.size)
            formation.physicsBody?.isDynamic = false
            formation.physicsBody?.friction = 0.2
            formation.physicsBody?.restitution = 0.1
            
            backgroundNode.addChild(formation)
        }
    }
    
    private func setupCamera() {
        cameraNode = SKCameraNode()
        camera = cameraNode
        addChild(cameraNode)
    }
    
    private func setupAvatar() {
        // Create a temporary colored rectangle for the avatar
        // Later we'll replace this with a proper sprite
        avatar = SKSpriteNode(color: .blue, size: CGSize(width: 40, height: 40))
        avatar.position = CGPoint(x: 0, y: 0)
        avatar.zPosition = 1
        
        // Add physics body to the avatar
        avatar.physicsBody = SKPhysicsBody(rectangleOf: avatar.size)
        avatar.physicsBody?.isDynamic = true
        avatar.physicsBody?.allowsRotation = false
        avatar.physicsBody?.friction = 0.0
        avatar.physicsBody?.restitution = 0.0
        avatar.physicsBody?.linearDamping = 0.0
        avatar.physicsBody?.categoryBitMask = avatarCategory
        avatar.physicsBody?.contactTestBitMask = enemyCategory
        avatar.physicsBody?.collisionBitMask = wallCategory | enemyCategory
        
        addChild(avatar)
    }
    
    private func setupHealthBar() {
        // Create the health bar background (gray)
        let healthBarBackground = SKShapeNode(rectOf: CGSize(width: 50, height: 8))
        healthBarBackground.fillColor = .gray
        healthBarBackground.strokeColor = .clear
        healthBarBackground.position = CGPoint(x: 0, y: 30) // Position above avatar
        healthBarBackground.zPosition = 2
        avatar.addChild(healthBarBackground)
        
        // Create the health bar (green)
        healthBar = SKShapeNode(rectOf: CGSize(width: 50, height: 8))
        healthBar.fillColor = .green
        healthBar.strokeColor = .clear
        healthBar.position = CGPoint(x: 0, y: 30) // Position above avatar
        healthBar.zPosition = 2
        avatar.addChild(healthBar)
        
        // Initialize health bar
        updateHealthBar()
    }
    
    private func updateHealthBar() {
        // Calculate health bar width based on lives (3 lives = full width)
        let healthPercentage = CGFloat(lives) / 3.0
        let newWidth = 50.0 * healthPercentage
        
        // Update health bar width
        healthBar.path = CGPath(rect: CGRect(x: -newWidth/2, y: -4, width: newWidth, height: 8), transform: nil)
        
        // Update color based on health
        if lives == 3 {
            healthBar.fillColor = .green
        } else if lives == 2 {
            healthBar.fillColor = .yellow
        } else if lives == 1 {
            healthBar.fillColor = .red
        }
    }
    
    private func setupPhysicsWorld() {
        physicsWorld.gravity = CGVector(dx: 0, dy: 0)
    }
    
    private func setupEnemyCounter() {
        enemyCounterLabel = SKLabelNode(text: "Enemies: 0")
        enemyCounterLabel.fontSize = 18
        enemyCounterLabel.fontColor = .white
        enemyCounterLabel.position = CGPoint(x: -size.width/2 + 20, y: size.height/2 - 35)
        enemyCounterLabel.zPosition = 10
        enemyCounterLabel.horizontalAlignmentMode = .left
        cameraNode.addChild(enemyCounterLabel)
        updateEnemyCounter()
    }
    
    private func updateEnemyCounter() {
        enemyCounterLabel.text = "Enemies: \(enemies.count)"
    }
    
    private func setupKillCounter() {
        enemiesKilledLabel = SKLabelNode(text: "Kills: 0")
        enemiesKilledLabel.fontSize = 16
        enemiesKilledLabel.fontColor = .white
        enemiesKilledLabel.position = CGPoint(x: -size.width/2 + 20, y: size.height/2 - 55)
        enemiesKilledLabel.zPosition = 10
        enemiesKilledLabel.horizontalAlignmentMode = .left
        cameraNode.addChild(enemiesKilledLabel)
    }
    
    private func setupSounds() {
        // Create shooting sound effect
        shootSound = SKAction.playSoundFileNamed("shoot.wav", waitForCompletion: false)
    }
    
    private func shootBullet() {
        // Create bullet
        let bullet = SKSpriteNode(color: .yellow, size: CGSize(width: 10, height: 10))
        bullet.position = avatar.position
        bullet.zPosition = 1
        
        // Add physics body
        bullet.physicsBody = SKPhysicsBody(circleOfRadius: 5)
        bullet.physicsBody?.isDynamic = true
        bullet.physicsBody?.categoryBitMask = bulletCategory
        bullet.physicsBody?.contactTestBitMask = enemyCategory
        bullet.physicsBody?.collisionBitMask = 0
        
        // Find nearest enemy
        if let targetEnemy = findNearestEnemy() {
            // Calculate direction to enemy
            let dx = targetEnemy.position.x - avatar.position.x
            let dy = targetEnemy.position.y - avatar.position.y
            let length = sqrt(dx * dx + dy * dy)
            
            // Normalize direction
            let normalizedDx = dx / length
            let normalizedDy = dy / length
            
            // Set velocity
            bullet.physicsBody?.velocity = CGVector(dx: normalizedDx * bulletSpeed, dy: normalizedDy * bulletSpeed)
        } else {
            // If no enemy found, shoot in a random direction
            let randomAngle = CGFloat.random(in: 0...(2 * .pi))
            bullet.physicsBody?.velocity = CGVector(dx: cos(randomAngle) * bulletSpeed, dy: sin(randomAngle) * bulletSpeed)
        }
        
        addChild(bullet)
        
        // Play shooting sound
        run(shootSound)
        
        // Remove bullet after 2 seconds
        let wait = SKAction.wait(forDuration: 2.0)
        let remove = SKAction.removeFromParent()
        bullet.run(SKAction.sequence([wait, remove]))
    }
    
    private func findNearestEnemy() -> SKSpriteNode? {
        var nearestEnemy: SKSpriteNode?
        var shortestDistance = CGFloat.infinity
        
        for enemy in enemies {
            let distance = self.distance(from: avatar.position, to: enemy.position)
            if distance < shortestDistance {
                shortestDistance = distance
                nearestEnemy = enemy
            }
        }
        
        return nearestEnemy
    }
    
    private func updateKillCounter() {
        enemiesKilledLabel.text = "Kills: \(enemiesKilled)"
        updateHighScore()
    }
    
    private func spawnEnemies() {
        // Clear any existing enemies first
        for enemy in enemies {
            enemy.removeFromParent()
        }
        enemies.removeAll()
        
        // Spawn exactly 2 enemies
        for _ in 0..<2 {
            spawnEnemy()
        }
        lastEnemySpawnTime = 5.0 // Set to spawn interval to prevent immediate spawn
    }
    
    private func spawnEnemy() {
        let enemy = SKSpriteNode(color: .red, size: CGSize(width: 30, height: 30))
        
        // Random position within the map boundaries
        let mapSize: CGFloat = 2000
        let margin: CGFloat = 100 // Keep enemies away from walls
        var x: CGFloat
        var y: CGFloat
        repeat {
            x = CGFloat.random(in: -mapSize/2 + margin...mapSize/2 - margin)
            y = CGFloat.random(in: -mapSize/2 + margin...mapSize/2 - margin)
        } while distance(from: CGPoint(x: x, y: y), to: avatar.position) < 200
        
        enemy.position = CGPoint(x: x, y: y)
        enemy.zPosition = 1
        
        // Add physics body
        enemy.physicsBody = SKPhysicsBody(rectangleOf: enemy.size)
        enemy.physicsBody?.isDynamic = true
        enemy.physicsBody?.categoryBitMask = enemyCategory
        enemy.physicsBody?.contactTestBitMask = avatarCategory | bulletCategory
        enemy.physicsBody?.collisionBitMask = avatarCategory | wallCategory
        
        // Store health in userData
        enemy.userData = NSMutableDictionary()
        enemy.userData?.setValue(1, forKey: "health")
        
        addChild(enemy)
        enemies.append(enemy)
        updateEnemyCounter()
        
        // Add random movement
        let randomDirection = CGVector(dx: CGFloat.random(in: -1...1),
                                     dy: CGFloat.random(in: -1...1))
        let normalizedDirection = normalize(vector: randomDirection)
        let movement = CGVector(dx: normalizedDirection.dx * enemySpeed,
                              dy: normalizedDirection.dy * enemySpeed)
        
        enemy.physicsBody?.velocity = movement
    }
    
    private func distance(from point1: CGPoint, to point2: CGPoint) -> CGFloat {
        let dx = point2.x - point1.x
        let dy = point2.y - point1.y
        return sqrt(dx * dx + dy * dy)
    }
    
    private func normalize(vector: CGVector) -> CGVector {
        let length = sqrt(vector.dx * vector.dx + vector.dy * vector.dy)
        if length == 0 {
            return vector
        }
        return CGVector(dx: vector.dx / length, dy: vector.dy / length)
    }
    
    // MARK: - Physics Contact
    func didBegin(_ contact: SKPhysicsContact) {
        let collision = contact.bodyA.categoryBitMask | contact.bodyB.categoryBitMask
        
        if collision == avatarCategory | enemyCategory {
            // Determine which body is the enemy
            let enemy = (contact.bodyA.categoryBitMask == enemyCategory) ? contact.bodyA.node : contact.bodyB.node
            
            if let enemyNode = enemy as? SKSpriteNode {
                // Create explosion at enemy position
                createExplosion(at: enemyNode.position, color: .red)
                
                // Remove the enemy
                enemyNode.removeFromParent()
                if let index = enemies.firstIndex(of: enemyNode) {
                    enemies.remove(at: index)
                }
                
                // Update kill counter
                enemiesKilled += 1
                updateKillCounter()
                
                // Decrease lives
                lives -= 1
                updateHealthBar()
                
                // Check for game over
                if lives <= 0 {
                    gameOver()
                }
            }
        } else if collision == bulletCategory | enemyCategory {
            // Determine which body is the enemy and which is the bullet
            let enemy = (contact.bodyA.categoryBitMask == enemyCategory) ? contact.bodyA.node : contact.bodyB.node
            let bullet = (contact.bodyA.categoryBitMask == bulletCategory) ? contact.bodyA.node : contact.bodyB.node
            
            if let enemyNode = enemy as? SKSpriteNode {
                // Create explosion at enemy position
                createExplosion(at: enemyNode.position, color: .red)
                
                // Remove the enemy
                enemyNode.removeFromParent()
                if let index = enemies.firstIndex(of: enemyNode) {
                    enemies.remove(at: index)
                }
                
                // Update kill counter
                enemiesKilled += 1
                updateKillCounter()
                
                // Remove the bullet
                bullet?.removeFromParent()
                
                // 30% chance to spawn a power-up
                if Double.random(in: 0...1) < 0.3 {
                    let enemyPosition = enemyNode.position
                    // 50% chance for each type of power-up
                    if Double.random(in: 0...1) < 0.5 {
                        spawnHealthPowerUpAt(position: enemyPosition)
                    } else {
                        spawnRapidFirePowerUpAt(position: enemyPosition)
                    }
                }
            }
        } else if collision == avatarCategory | powerUpCategory {
            // Determine which body is the power-up
            let powerUp = (contact.bodyA.categoryBitMask == powerUpCategory) ? contact.bodyA.node : contact.bodyB.node
            
            if let powerUpNode = powerUp as? SKSpriteNode {
                if powerUpNode.name == "healthPowerUp" {
                    // Health power-up logic
                    lives = min(lives + 1, 3)
                    updateHealthBar()
                } else if powerUpNode.name == "rapidFirePowerUp" {
                    // Rapid Fire power-up logic
                    hasRapidFire = true
                    rapidFireEndTime = gameTime + rapidFireDuration
                    print("Rapid Fire activated at time: \(gameTime), will expire at: \(rapidFireEndTime)")
                }
                
                // Remove the power-up
                powerUpNode.removeFromParent()
            }
        }
    }
    
    // MARK: - Touch Handling
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let location = touch.location(in: self)
        
        if isGameOver {
            // Check if retry button was tapped
            let nodes = nodes(at: location)
            for node in nodes {
                if node.name == "retryButton" {
                    resetGame()
                    return
                }
            }
            return
        }
        
        // Check if pause button was tapped
        let nodes = nodes(at: location)
        for node in nodes {
            if node.name == "pauseButton" {
                togglePause()
                return
            }
        }
        
        // Only process movement if game is not paused and not over
        if !gameIsPaused && !isGameOver {
            lastTouchLocation = location
        }
    }
    
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        lastTouchLocation = touch.location(in: self)
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        lastTouchLocation = nil
        avatar.physicsBody?.velocity = .zero
    }
    
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        lastTouchLocation = nil
        avatar.physicsBody?.velocity = .zero
    }
    
    private func createExplosion(at position: CGPoint, color: UIColor) {
        let explosionPieces = 8 // Number of pieces in the explosion
        let pieceSize: CGFloat = 5.0
        let explosionRadius: CGFloat = 20.0
        let explosionDuration: TimeInterval = 0.5
        
        // Create explosion pieces
        for i in 0..<explosionPieces {
            let piece = SKSpriteNode(color: color, size: CGSize(width: pieceSize, height: pieceSize))
            piece.position = position
            piece.zPosition = 100 // Ensure pieces appear above other elements
            
            // Calculate direction for each piece
            let angle = (CGFloat(i) / CGFloat(explosionPieces)) * CGFloat.pi * 2
            let dx = cos(angle) * explosionRadius
            let dy = sin(angle) * explosionRadius
            
            // Create movement action
            let moveAction = SKAction.moveBy(x: dx, y: dy, duration: explosionDuration)
            let fadeAction = SKAction.fadeOut(withDuration: explosionDuration)
            let scaleAction = SKAction.scale(to: 0.1, duration: explosionDuration)
            let group = SKAction.group([moveAction, fadeAction, scaleAction])
            let remove = SKAction.removeFromParent()
            
            // Run the animation sequence
            piece.run(SKAction.sequence([group, remove]))
            addChild(piece)
        }
    }
    
    private func gameOver() {
        isGameOver = true
        
        // Create explosion animation for avatar
        createExplosion(at: avatar.position, color: .red)
        
        // Hide the avatar
        avatar.isHidden = true
        
        // Update high score one final time
        updateHighScore()
        
        // Create game over text
        let gameOverText = SKLabelNode(text: "Game Over")
        gameOverText.fontSize = 40
        gameOverText.fontColor = .red
        gameOverText.position = CGPoint(x: 0, y: 50)
        gameOverText.zPosition = 100
        cameraNode.addChild(gameOverText)
        
        // Create retry button
        retryButton = SKLabelNode(text: "Retry")
        retryButton.fontSize = 30
        retryButton.fontColor = .white
        retryButton.position = CGPoint(x: 0, y: 0)
        retryButton.zPosition = 100
        retryButton.name = "retryButton"
        cameraNode.addChild(retryButton)
    }
    
    private func resetGame() {
        // Remove game over UI
        cameraNode.children.forEach { node in
            if node is SKLabelNode && node != timerLabel && node != enemyCounterLabel && node != enemiesKilledLabel && node != pauseButton && node != pauseText {
                node.removeFromParent()
            }
        }
        
        // Reset game state
        isGameOver = false
        gameTime = 0
        enemiesKilled = 0
        hasRapidFire = false
        
        // Reset avatar
        avatar.position = CGPoint(x: size.width/2, y: size.height/2)
        avatar.physicsBody?.velocity = .zero
        avatar.isHidden = false // Make sure avatar is visible again
        lives = 3
        updateHealthBar()
        
        // Remove all enemies
        enemies.forEach { $0.removeFromParent() }
        enemies.removeAll()
        
        // Reset UI
        updateEnemyCounter()
        updateKillCounter()
        updateTimer()
        
        // Reset timers
        lastEnemySpawnTime = 0
        lastPowerUpSpawnTime = 0
        lastShootTime = 0
        
        // Update high score display
        updateHighScore()
        
        // Re-setup UI to ensure high score label is present
        setupUI()
    }
    
    // MARK: - Game Loop
    override func update(_ currentTime: TimeInterval) {
        // Update camera position to follow avatar
        cameraNode.position = avatar.position
        
        // Only update game if not paused and not over
        if !gameIsPaused && !isGameOver {
            // Update avatar position based on touch
            if let touchLocation = lastTouchLocation {
                let dx = touchLocation.x - avatar.position.x
                let dy = touchLocation.y - avatar.position.y
                let length = sqrt(dx * dx + dy * dy)
                
                if length > 5 { // Only move if we're not very close to the target
                    let normalizedDx = dx / length
                    let normalizedDy = dy / length
                    let speed: CGFloat = 100.0 // Reduced from 200.0 to 100.0 for slower movement
                    
                    avatar.physicsBody?.velocity = CGVector(dx: normalizedDx * speed, dy: normalizedDy * speed)
                } else {
                    avatar.physicsBody?.velocity = .zero
                    lastTouchLocation = nil
                }
            }
            
            // Update enemy positions
            updateEnemies()
            
            // Update game time
            gameTime += 1/60 // Assuming 60 FPS
            updateTimer()
            
            // Check if rapid fire power-up has expired
            if hasRapidFire && gameTime >= rapidFireEndTime {
                hasRapidFire = false
                print("Rapid Fire expired at time: \(gameTime)")
            }
            
            // Check if it's time to shoot
            let currentCooldown = hasRapidFire ? rapidFireCooldown : shootCooldown
            if gameTime - lastShootTime >= currentCooldown {
                shootBullet()
                lastShootTime = gameTime
                if hasRapidFire {
                    print("Rapid Fire shot at time: \(gameTime), next shot in \(rapidFireCooldown) seconds")
                } else {
                    print("Normal shot at time: \(gameTime), next shot in \(shootCooldown) seconds")
                }
            }
            
            // Check if it's time to spawn a power-up
            if gameTime - lastPowerUpSpawnTime >= powerUpSpawnInterval {
                if Double.random(in: 0...1) < powerUpSpawnChance {
                    // Randomly choose between health and rapid fire power-up
                    if Bool.random() {
                        spawnHealthPowerUp()
                    } else {
                        spawnRapidFirePowerUp()
                    }
                }
                lastPowerUpSpawnTime = gameTime
            }
            
            // Check if it's time to spawn a new enemy
            if gameTime - lastEnemySpawnTime >= enemySpawnInterval {
                spawnEnemy()
                lastEnemySpawnTime = gameTime
            }
        }
    }
    
    private func updateEnemies() {
        for enemy in enemies {
            if !isGameOver {
                // Calculate direction to avatar
                let dx = avatar.position.x - enemy.position.x
                let dy = avatar.position.y - enemy.position.y
                let length = sqrt(dx * dx + dy * dy)
                
                // Normalize direction
                let normalizedDx = dx / length
                let normalizedDy = dy / length
                
                // Set velocity towards avatar
                enemy.physicsBody?.velocity = CGVector(dx: normalizedDx * enemySpeed, dy: normalizedDy * enemySpeed)
            } else {
                // Stop moving when game is over
                enemy.physicsBody?.velocity = CGVector(dx: 0, dy: 0)
            }
        }
    }
    
    private func setupPauseButton() {
        pauseButton = SKLabelNode(text: "⏸")
        pauseButton.fontSize = 40
        pauseButton.fontColor = .white
        pauseButton.position = CGPoint(x: size.width/2 - 40, y: size.height/2 - 40)
        pauseButton.zPosition = 100
        pauseButton.name = "pauseButton"
        cameraNode.addChild(pauseButton)
        
        pauseText = SKLabelNode(text: "PAUSED")
        pauseText.fontSize = 50
        pauseText.fontColor = .white
        pauseText.position = CGPoint(x: 0, y: 0)
        pauseText.zPosition = 100
        pauseText.isHidden = true
        cameraNode.addChild(pauseText)
    }
    
    private func togglePause() {
        gameIsPaused = !gameIsPaused
        
        if gameIsPaused {
            // Show pause text
            pauseText.isHidden = false
            // Stop all movement
            avatar.physicsBody?.velocity = .zero
            lastTouchLocation = nil
            // Stop all enemies
            enemies.forEach { $0.physicsBody?.velocity = .zero }
        } else {
            // Hide pause text
            pauseText.isHidden = true
        }
    }
    
    private func setupTimer() {
        timerLabel = SKLabelNode(text: "Time: 0:00")
        timerLabel.fontSize = 16
        timerLabel.fontColor = .white
        timerLabel.position = CGPoint(x: size.width/2 - 100, y: size.height/2 - 80)
        timerLabel.zPosition = 10
        timerLabel.horizontalAlignmentMode = .left
        cameraNode.addChild(timerLabel)
    }
    
    private func updateTimer() {
        let minutes = Int(gameTime) / 60
        let seconds = Int(gameTime) % 60
        timerLabel.text = String(format: "Time: %d:%02d", minutes, seconds)
    }
    
    private func setupWalls() {
        // Create border walls
        let wallThickness: CGFloat = 20
        let mapSize: CGFloat = 2000 // Size of the playable area
        
        // Top wall
        let topWall = SKSpriteNode(color: .gray, size: CGSize(width: mapSize + wallThickness * 2, height: wallThickness))
        topWall.position = CGPoint(x: 0, y: mapSize/2 + wallThickness/2)
        topWall.physicsBody = SKPhysicsBody(rectangleOf: topWall.size)
        topWall.physicsBody?.isDynamic = false
        topWall.physicsBody?.categoryBitMask = wallCategory
        topWall.physicsBody?.contactTestBitMask = avatarCategory | enemyCategory
        topWall.physicsBody?.collisionBitMask = avatarCategory | enemyCategory
        addChild(topWall)
        
        // Bottom wall
        let bottomWall = SKSpriteNode(color: .gray, size: CGSize(width: mapSize + wallThickness * 2, height: wallThickness))
        bottomWall.position = CGPoint(x: 0, y: -mapSize/2 - wallThickness/2)
        bottomWall.physicsBody = SKPhysicsBody(rectangleOf: bottomWall.size)
        bottomWall.physicsBody?.isDynamic = false
        bottomWall.physicsBody?.categoryBitMask = wallCategory
        bottomWall.physicsBody?.contactTestBitMask = avatarCategory | enemyCategory
        bottomWall.physicsBody?.collisionBitMask = avatarCategory | enemyCategory
        addChild(bottomWall)
        
        // Left wall
        let leftWall = SKSpriteNode(color: .gray, size: CGSize(width: wallThickness, height: mapSize))
        leftWall.position = CGPoint(x: -mapSize/2 - wallThickness/2, y: 0)
        leftWall.physicsBody = SKPhysicsBody(rectangleOf: leftWall.size)
        leftWall.physicsBody?.isDynamic = false
        leftWall.physicsBody?.categoryBitMask = wallCategory
        leftWall.physicsBody?.contactTestBitMask = avatarCategory | enemyCategory
        leftWall.physicsBody?.collisionBitMask = avatarCategory | enemyCategory
        addChild(leftWall)
        
        // Right wall
        let rightWall = SKSpriteNode(color: .gray, size: CGSize(width: wallThickness, height: mapSize))
        rightWall.position = CGPoint(x: mapSize/2 + wallThickness/2, y: 0)
        rightWall.physicsBody = SKPhysicsBody(rectangleOf: rightWall.size)
        rightWall.physicsBody?.isDynamic = false
        rightWall.physicsBody?.categoryBitMask = wallCategory
        rightWall.physicsBody?.contactTestBitMask = avatarCategory | enemyCategory
        rightWall.physicsBody?.collisionBitMask = avatarCategory | enemyCategory
        addChild(rightWall)
    }
    
    private func spawnHealthPowerUp() {
        // Create heart shape
        let heartShape = SKShapeNode(path: createHeartPath())
        heartShape.fillColor = .red
        heartShape.strokeColor = .white
        heartShape.lineWidth = 2
        
        // Create container node for the heart
        let powerUp = SKSpriteNode(color: .clear, size: CGSize(width: 20, height: 20))
        powerUp.addChild(heartShape)
        powerUp.name = "healthPowerUp"
        
        // Random position within the map boundaries
        let mapSize: CGFloat = 2000
        let margin: CGFloat = 100 // Keep power-ups away from walls
        var x: CGFloat
        var y: CGFloat
        repeat {
            x = CGFloat.random(in: -mapSize/2 + margin...mapSize/2 - margin)
            y = CGFloat.random(in: -mapSize/2 + margin...mapSize/2 - margin)
        } while distance(from: CGPoint(x: x, y: y), to: avatar.position) < 200
        
        powerUp.position = CGPoint(x: x, y: y)
        powerUp.zPosition = 1
        
        // Add physics body
        powerUp.physicsBody = SKPhysicsBody(circleOfRadius: 10)
        powerUp.physicsBody?.isDynamic = false
        powerUp.physicsBody?.categoryBitMask = powerUpCategory
        powerUp.physicsBody?.contactTestBitMask = avatarCategory
        powerUp.physicsBody?.collisionBitMask = 0
        
        // Add pulsing animation
        let scaleUp = SKAction.scale(to: 1.2, duration: 0.5)
        let scaleDown = SKAction.scale(to: 0.8, duration: 0.5)
        let pulse = SKAction.sequence([scaleUp, scaleDown])
        powerUp.run(SKAction.repeatForever(pulse))
        
        addChild(powerUp)
        
        // Remove power-up after 10 seconds if not collected
        let wait = SKAction.wait(forDuration: 10.0)
        let remove = SKAction.removeFromParent()
        powerUp.run(SKAction.sequence([wait, remove]))
    }
    
    private func createHeartPath() -> CGPath {
        let path = CGMutablePath()
        let size: CGFloat = 10
        
        path.move(to: CGPoint(x: 0, y: size/4))
        path.addCurve(to: CGPoint(x: 0, y: size),
                     control1: CGPoint(x: -size/2, y: size/2),
                     control2: CGPoint(x: -size/2, y: size))
        path.addCurve(to: CGPoint(x: 0, y: size/4),
                     control1: CGPoint(x: size/2, y: size),
                     control2: CGPoint(x: size/2, y: size/2))
        path.addCurve(to: CGPoint(x: 0, y: -size/4),
                     control1: CGPoint(x: size/2, y: 0),
                     control2: CGPoint(x: size/2, y: -size/2))
        path.addCurve(to: CGPoint(x: 0, y: size/4),
                     control1: CGPoint(x: -size/2, y: -size/2),
                     control2: CGPoint(x: -size/2, y: 0))
        
        return path
    }
    
    private func spawnRapidFirePowerUp() {
        // Create lightning bolt shape
        let lightningShape = SKShapeNode(path: createLightningPath())
        lightningShape.fillColor = .yellow
        lightningShape.strokeColor = .orange
        lightningShape.lineWidth = 2
        
        // Create container node for the lightning
        let powerUp = SKSpriteNode(color: .clear, size: CGSize(width: 20, height: 20))
        powerUp.addChild(lightningShape)
        powerUp.name = "rapidFirePowerUp"
        
        // Random position within the map boundaries
        let mapSize: CGFloat = 2000
        let margin: CGFloat = 100 // Keep power-ups away from walls
        var x: CGFloat
        var y: CGFloat
        repeat {
            x = CGFloat.random(in: -mapSize/2 + margin...mapSize/2 - margin)
            y = CGFloat.random(in: -mapSize/2 + margin...mapSize/2 - margin)
        } while distance(from: CGPoint(x: x, y: y), to: avatar.position) < 200
        
        powerUp.position = CGPoint(x: x, y: y)
        powerUp.zPosition = 1
        
        // Add physics body
        powerUp.physicsBody = SKPhysicsBody(circleOfRadius: 10)
        powerUp.physicsBody?.isDynamic = false
        powerUp.physicsBody?.categoryBitMask = powerUpCategory
        powerUp.physicsBody?.contactTestBitMask = avatarCategory
        powerUp.physicsBody?.collisionBitMask = 0
        
        // Add pulsing animation
        let scaleUp = SKAction.scale(to: 1.2, duration: 0.5)
        let scaleDown = SKAction.scale(to: 0.8, duration: 0.5)
        let pulse = SKAction.sequence([scaleUp, scaleDown])
        powerUp.run(SKAction.repeatForever(pulse))
        
        addChild(powerUp)
        
        // Remove power-up after 10 seconds if not collected
        let wait = SKAction.wait(forDuration: 10.0)
        let remove = SKAction.removeFromParent()
        powerUp.run(SKAction.sequence([wait, remove]))
    }
    
    private func createLightningPath() -> CGPath {
        let path = CGMutablePath()
        let size: CGFloat = 10
        
        // Create a lightning bolt shape
        path.move(to: CGPoint(x: 0, y: size/2))
        path.addLine(to: CGPoint(x: -size/4, y: size/4))
        path.addLine(to: CGPoint(x: size/4, y: 0))
        path.addLine(to: CGPoint(x: -size/4, y: -size/4))
        path.addLine(to: CGPoint(x: 0, y: -size/2))
        path.addLine(to: CGPoint(x: size/4, y: -size/4))
        path.addLine(to: CGPoint(x: -size/4, y: 0))
        path.addLine(to: CGPoint(x: size/4, y: size/4))
        path.closeSubpath()
        
        return path
    }
    
    private func spawnHealthPowerUpAt(position: CGPoint) {
        // Create heart shape
        let heartShape = SKShapeNode(path: createHeartPath())
        heartShape.fillColor = .red
        heartShape.strokeColor = .white
        heartShape.lineWidth = 2
        
        // Create container node for the heart
        let powerUp = SKSpriteNode(color: .clear, size: CGSize(width: 20, height: 20))
        powerUp.addChild(heartShape)
        powerUp.name = "healthPowerUp"
        powerUp.position = position
        powerUp.zPosition = 1
        
        // Add physics body
        powerUp.physicsBody = SKPhysicsBody(circleOfRadius: 10)
        powerUp.physicsBody?.isDynamic = false
        powerUp.physicsBody?.categoryBitMask = powerUpCategory
        powerUp.physicsBody?.contactTestBitMask = avatarCategory
        powerUp.physicsBody?.collisionBitMask = 0
        
        // Add pulsing animation
        let scaleUp = SKAction.scale(to: 1.2, duration: 0.5)
        let scaleDown = SKAction.scale(to: 0.8, duration: 0.5)
        let pulse = SKAction.sequence([scaleUp, scaleDown])
        powerUp.run(SKAction.repeatForever(pulse))
        
        addChild(powerUp)
        
        // Remove power-up after 10 seconds if not collected
        let wait = SKAction.wait(forDuration: 10.0)
        let remove = SKAction.removeFromParent()
        powerUp.run(SKAction.sequence([wait, remove]))
    }
    
    private func spawnRapidFirePowerUpAt(position: CGPoint) {
        // Create lightning bolt shape
        let lightningShape = SKShapeNode(path: createLightningPath())
        lightningShape.fillColor = .yellow
        lightningShape.strokeColor = .orange
        lightningShape.lineWidth = 2
        
        // Create container node for the lightning
        let powerUp = SKSpriteNode(color: .clear, size: CGSize(width: 20, height: 20))
        powerUp.addChild(lightningShape)
        powerUp.name = "rapidFirePowerUp"
        powerUp.position = position
        powerUp.zPosition = 1
        
        // Add physics body
        powerUp.physicsBody = SKPhysicsBody(circleOfRadius: 10)
        powerUp.physicsBody?.isDynamic = false
        powerUp.physicsBody?.categoryBitMask = powerUpCategory
        powerUp.physicsBody?.contactTestBitMask = avatarCategory
        powerUp.physicsBody?.collisionBitMask = 0
        
        // Add pulsing animation
        let scaleUp = SKAction.scale(to: 1.2, duration: 0.5)
        let scaleDown = SKAction.scale(to: 0.8, duration: 0.5)
        let pulse = SKAction.sequence([scaleUp, scaleDown])
        powerUp.run(SKAction.repeatForever(pulse))
        
        addChild(powerUp)
        
        // Remove power-up after 10 seconds if not collected
        let wait = SKAction.wait(forDuration: 10.0)
        let remove = SKAction.removeFromParent()
        powerUp.run(SKAction.sequence([wait, remove]))
    }
    
    private func setupUI() {
        // Add high score label
        highScoreLabel = SKLabelNode(text: "High Score: 0")
        highScoreLabel.fontSize = 16
        highScoreLabel.fontColor = .yellow
        highScoreLabel.position = CGPoint(x: size.width/2 - 50, y: size.height/2 - 100)
        highScoreLabel.zPosition = 100
        cameraNode.addChild(highScoreLabel)
        
        // Update high score display
        updateHighScore()
    }
    
    private func updateHighScore() {
        if enemiesKilled > highScore {
            highScore = enemiesKilled
        }
        highScoreLabel.text = "High Score: \(highScore)"
    }
}

