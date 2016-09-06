//
//  ViewController.swift
//  The Game Of Life
//
//  Created by Dmitry Kozlov on 05/12/14.
//  Copyright (c) 2014 Dmitry Kozlov. All rights reserved.
//

import UIKit

// добавить заготовки

var viewController: ViewController?

let screenSize = UIScreen.mainScreen().bounds.size
let screenScale = UIScreen.mainScreen().scale
let screenCenter = CGPoint(x: screenSize.width/2, y: screenSize.height/2)

let fadeSpeed = 0.2
var map: Map = Map(width: 16, height: 16)

var inBackground = false
var memoryWarning = false

let chunkWidth: Int = Int(screenSize.width)/16
let chunkHeight: Int = Int(screenSize.height)/16
let chunkWidth1: Int = chunkWidth-1
let chunkHeight1: Int = chunkHeight-1
let chunkWidth2: Int = chunkWidth-2
let chunkHeight2: Int = chunkHeight-2

let mapWidth = chunkWidth * map.width
let mapHeight = chunkHeight * map.height

let bitmapBytesPerRow = Int(chunkWidth) * 4
let bitmapByteCount = bitmapBytesPerRow * Int(chunkHeight)

let colorSpace = CGColorSpaceCreateDeviceRGB()

let zoomMin: CGFloat = 1.0
let zoomMax: CGFloat = 60.0

var lifeColor = 1

var eventRed: UInt8 = 0
var eventGreen: UInt8 = 0
var eventBlue: UInt8 = 0

var eventSecondRed: UInt8 = 235
var eventSecondGreen: UInt8 = 235
var eventSecondBlue: UInt8 = 235

var event = "No events"

class ViewController: UIViewController {
    @IBOutlet weak var speedLabel: UILabel!
    @IBOutlet weak var nextTurnButton: UIButton!
    @IBOutlet weak var clearButton: UIButton!
    @IBOutlet weak var gameView: UIView!
    @IBOutlet weak var framesPerSecondLabel: UILabel!
    @IBOutlet weak var stopButton: UISegmentedControl!
    @IBOutlet weak var infoView: UIScrollView!
    @IBOutlet weak var eventsLabel: UILabel!
    
    @IBOutlet weak var liveColorSegment: UISegmentedControl!
    var timer: NSTimer?
    var speed: Int = 20
    var forceStop = true
    var fillType = false
    
    var tfDistance: Float = 0.0
    var tfZoom: CGFloat = 0.0
    var tfPosition = CGPoint()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        if File.exists("Event.life") {
            let liveColorString: String? = File.read("Event.life")
            if liveColorString != nil {
                print("\(lifeColor)")
                lifeColor = Int(liveColorString!)!
                liveColorSegment.selectedSegmentIndex = lifeColor
            }
        }
        
        let twoFingerGesture = UIPanGestureRecognizer(target: self, action: "twoFingerGesture:")
        twoFingerGesture.minimumNumberOfTouches = 2
        twoFingerGesture.maximumNumberOfTouches = 2
        gameView.addGestureRecognizer(twoFingerGesture)
        
        let oneFingerGesture = UIPanGestureRecognizer(target: self, action: "oneFingerGesture:")
        oneFingerGesture.minimumNumberOfTouches = 1
        oneFingerGesture.maximumNumberOfTouches = 1
        gameView.addGestureRecognizer(oneFingerGesture)
        
        let tapGesture = UITapGestureRecognizer(target: self, action: "tapGesture:")
        tapGesture.numberOfTapsRequired = 1
        tapGesture.numberOfTouchesRequired = 1
        gameView.addGestureRecognizer(tapGesture)
        
        let holdFingerGesture = UILongPressGestureRecognizer(target: self, action: "oneFingerGesture:")
        //view.addGestureRecognizer(holdFingerGesture)
        
        findEventColor()
        eventsLabel.text = event
        
        gameView.addSubview(map.view)
        self.framesPerSecondLabel.alpha = 0.0
        self.stopButton.selectedSegmentIndex = 1
        
        infoView.layer.cornerRadius = 6
        infoView.contentSize = CGSize(width: 320, height: 410)
        infoView.hidden = true
        
        viewController = self
    }
    
    func doubleTapGesture(gesture: UITapGestureRecognizer) {
        let position = gesture.locationInView(map.view)
        let screenPosition = gesture.locationInView(view)
        
        let zoom = map.zoom * 2.0
        let x = -position.x + screenCenter.x
        let y = -position.y + screenCenter.y
        
        map.animatedZoom(zoom)
        UIView.animateWithDuration(0.3, animations: {
            map.view.frame = CGRect(x: x, y: y, width: 0, height: 0)
        })
    }
    
    func twoFingerGesture(gesture: UIPanGestureRecognizer) {
        if gesture.numberOfTouches() != 2 {
            return
        }
        let pos1 = gesture.locationOfTouch(0, inView: map.view)
        let pos2 = gesture.locationOfTouch(1, inView: map.view)
        
        let sPos1 = gesture.locationOfTouch(0, inView: view)
        let sPos2 = gesture.locationOfTouch(1, inView: view)
        
        let dx = pos2.x - pos1.x
        let dy = pos2.y - pos1.y
        let dist2 = Float(dx*dx + dy*dy)
        let distance = sqrtf(dist2);
        
        switch gesture.state {
        case .Began:
            tfZoom = map.zoom
            tfDistance = distance
            tfPosition = CGPoint(x: (pos1.x + pos2.x) / 2.0, y: (pos1.y + pos2.y) / 2.0)
        case .Changed:
            let screenPosition = CGPoint(x: (sPos1.x + sPos2.x) / 2.0, y: (sPos1.y + sPos2.y) / 2.0)
            
            var zoomOffset = CGFloat(distance) / CGFloat(tfDistance)
            var zoom = tfZoom * zoomOffset
            
            if zoom < zoomMin {
                zoom = zoomMin
                zoomOffset = zoom / tfZoom
            } else if zoom > zoomMax {
                zoom = zoomMax
                zoomOffset = zoom / tfZoom
            }
            map.setZoom(zoom)
            
            let x = -tfPosition.x * zoomOffset + screenPosition.x
            let y = -tfPosition.y * zoomOffset + screenPosition.y
            
            let maxX = CGFloat(mapWidth) * -zoom + CGFloat(mapWidth)
            let maxY = CGFloat(mapHeight) * -zoom + CGFloat(mapHeight)
            
            map.view.frame = CGRect(x: x > 0 ? 0 : x < maxX ? maxX : x , y: y > 0 ? 0 : y < maxY ? maxY : y, width: 0, height: 0)
        default:
            break
        }
    }
    func oneFingerGesture(gesture: UIGestureRecognizer) {
        
        let pos = gesture.locationInView(map.view)
        switch gesture.state {
        case .Began:
            stop()
            fillType = !map.getPixel(pos)
            let hitbox = map.setPixel(pos, type: fillType)
        case .Changed:
            let hitbox = map.setPixel(pos, type: fillType)
        case .Ended:
            start()
        default:
            break
        }
    }
    func tapGesture(gesture: UITapGestureRecognizer) {
        let pos = gesture.locationInView(map.view)
        fillType = !map.getPixel(pos)
        let hitbox = map.setPixel(pos, type: fillType)
    }
    @IBAction func speedDown(sender: UISlider) {
        UIView.animateWithDuration(fadeSpeed, animations: {self.framesPerSecondLabel.alpha = 1.0})
        stop()
    }
    @IBAction func speedUpInside(sender: UISlider) {
        UIView.animateWithDuration(fadeSpeed, animations: {self.framesPerSecondLabel.alpha = 0.0})
        start()
    }
    @IBAction func speedUpOutside(sender: UISlider) {
        UIView.animateWithDuration(fadeSpeed, animations: {self.framesPerSecondLabel.alpha = 0.0})
        start()
    }
    @IBAction func changeSpeed(sender: UISlider) {
        speed = Int(sender.value)
        speedLabel.text = "\(speed)"
    }
    @IBAction func pause(sender: UISegmentedControl) {
        if sender.selectedSegmentIndex == 0 {
            unpause()
        } else {
            pause()
        }
    }
    @IBAction func nextTurn(sender: UIButton) {
        map.turn()
    }
    @IBAction func clear(sender: AnyObject) {
        pause()
        map.clear()
    }
    @IBAction func lifeColorChanged(sender: UISegmentedControl) {
        lifeColor = sender.selectedSegmentIndex
        for i in 0...map.width1 {
            for j in 0...map.height1 {
                let chunk = map.chunks[i][j]
                if chunk.current.sum() > 0 {
                    chunk.redraw()
                }
            }
        }
    }
    @IBAction func infoButtonUp(sender: UIButton) {
        if sender.tag == 0 {
            sender.tag = 1
            self.infoView.hidden = false
            UIView.animateWithDuration(0.3, animations: {self.infoView.alpha = 0.9})
        } else {
            sender.tag = 0
            UIView.animateWithDuration(0.3, animations: {self.infoView.alpha = 0}, completion: {ended in if ended {self.infoView.hidden = true}})
        }
    }
    
    func update() {
        map.turn()
    }
    func pause() {
        if forceStop {
            return
        }
        forceStop = true
        UIView.animateWithDuration(fadeSpeed, animations: {self.nextTurnButton.alpha = 1.0})
        stop()
    }
    func unpause() {
        if !forceStop {
            return
        }
        forceStop = false
        UIView.animateWithDuration(fadeSpeed, animations: {self.nextTurnButton.alpha = 0.0})
        start()
    }
    func stop() {
        stopButton.selectedSegmentIndex = 1
        timer?.invalidate()
        timer = nil
    }
    func start() {
        if !forceStop {
            stopButton.selectedSegmentIndex = 0
            if (timer?.valid == nil) {
                let interval = 1.0 / Double(speed)
                timer = NSTimer.scheduledTimerWithTimeInterval(interval, target: self, selector: Selector("update"), userInfo: nil, repeats: true)
            }
        }
    }
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
        
    }
    override func preferredStatusBarStyle() -> UIStatusBarStyle {
        return UIStatusBarStyle.LightContent
    }
}

class Map {
    var chunks: [[Chunk]]
    var lifes = 0
    
    let chunksCount: Int
    var turnsCompleted = 0
    var drawsCompleted = 0
    
    let width: Int
    let height: Int
    let width1: Int
    let height1: Int
    
    var zoom: CGFloat = 1.0
    let view: UIView
    init (width: Int, height: Int) {
        self.width = width
        self.height = height
        self.width1 = width-1
        self.height1 = height-1
        self.chunks = [[Chunk]]()
        self.view = UIView()
        self.chunksCount = width * height
        for i in 0...width-1 {
            var chunkArray = [Chunk]()
            for j in 0...height-1 {
                let chunk = Chunk(x: i, y: j)
                self.view.addSubview(chunk.view)
                chunkArray.append(chunk)
            }
            self.chunks.append(chunkArray)
        }
        
    }
    func getPixel(position: CGPoint) -> Bool {
        if position.x < 0 || position.y < 0 {
            return false
        }
        var x = Int(position.x / zoom)
        var y = Int(position.y / zoom)
        let chunkX = Int(Float(x) / Float(chunkWidth))
        let chunkY = Int(Float(y) / Float(chunkHeight))
        if chunkX > map.width1 || chunkY > map.height1 {
            return false
        }
        x = x - chunkWidth * chunkX
        y = y - chunkHeight * chunkY
        let chunk = chunks[chunkX][chunkY]
        return chunk.tiles[x][y]
    }
    func setPixel(position: CGPoint, type: Bool) -> Bool {
        if position.x < 0 || position.y < 0 {
            return false
        }
        var x = Int(position.x / zoom)
        var y = Int(position.y / zoom)
        let chunkX = Int(Float(x) / Float(chunkWidth))
        let chunkY = Int(Float(y) / Float(chunkHeight))
        if chunkX > map.width1 || chunkY > map.height1 {
            return false
        }
        x = x - chunkWidth * chunkX
        y = y - chunkHeight * chunkY
        
        let chunk = chunks[chunkX][chunkY]
        if chunk.tiles[x][y] == type {
            return false
        }
        else {
            chunk.setTile(type, x: x, y: y)
            chunk.draw()
            return true
        }
    }
    func setZoom(zoom: CGFloat) {
        if self.zoom != zoom {
            self.zoom = zoom
            let ww = zoom * CGFloat(chunkWidth)
            let hh = zoom * CGFloat(chunkHeight)
            for i in 0...width-1 {
                for j in 0...height-1 {
                    let chunk = chunks[i][j]
                    chunk.view.frame = CGRectMake(CGFloat(i) * ww, CGFloat(j) * hh, ww, hh)
                }
            }
        }
    }
    func animatedZoom(zoom: CGFloat) {
        self.zoom = zoom
        let ww = zoom * CGFloat(chunkWidth)
        let hh = zoom * CGFloat(chunkHeight)
        for i in 0...width-1 {
            for j in 0...height-1 {
                let chunk = chunks[i][j]
                UIView .animateWithDuration(0.3, animations: {chunk.view.frame = CGRectMake(CGFloat(i) * ww, CGFloat(j) * hh, ww, hh)})
            }
        }
    }
    func turn() {
        for i in 0...width-1 {
            for j in 0...height-1 {
                chunks[i][j].turn()
            }
        }
        for i in 0...width-1 {
            for j in 0...height-1 {
                chunks[i][j].apply()
            }
        }
    }
    func clear() {
        for i in 0...width-1 {
            for j in 0...height-1 {
                chunks[i][j].clear()
            }
        }
    }
    func draw() {
        for i in 0...width-1 {
            for j in 0...height-1 {
                chunks[i][j].redraw()
            }
        }
    }
}


class Chunk {
    var tiles: [[Bool]]
    var tilesNew: [[Bool]]
    
    let x: Int
    let y: Int
    
    let current = ChunkLifes()
    let changed = ChunkChanges()
    let currentNew = ChunkLifes()
    let changedNew = ChunkChanges()
    
    var clean = true
    var active = false
    var activeNew = false
    var changes = false
    
    let view: UIImageView
    
    let bitmapData = malloc(CUnsignedLong(bitmapByteCount))
    var dataType: UnsafeMutablePointer<UInt8>
    
    
    // MARK: Init
    init (x:Int, y: Int) {
        self.x = x
        self.y = y
        self.tiles = [[Bool]](count: chunkWidth, repeatedValue: [Bool](count: chunkHeight, repeatedValue: false))
        tilesNew = tiles
        self.view = UIImageView(frame: CGRect(x: x * chunkWidth, y: y * chunkHeight, width: chunkWidth, height: chunkHeight))
        self.view.layer.magnificationFilter = kCAFilterNearest
        
        dataType = UnsafeMutablePointer<UInt8>(bitmapData)
        
        firstDraw()
    }
    // MARK: Turn
    func turn() {
        if active {
            tilesNew = tiles
            changes = false
            
            
            currentNew.merge(current)
            
            let tChunk = topChunk()
            let bChunk = bottomChunk()
            let lChunk = leftChunk()
            let rChunk = rightChunk()
            
            let tlChunk = topLeftChunk()
            let trChunk = topRightChunk()
            let blChunk = bottomLeftChunk()
            let brChunk = bottomRightChunk()
            
            let tb = Bool(tChunk.current.bottom)
            let bt = Bool(bChunk.current.top)
            let lr = Bool(lChunk.current.right)
            let rl = Bool(rChunk.current.left)
            
            let tlbr = tlChunk.current.bottomRight
            let trbl = trChunk.current.bottomLeft
            let bltr = blChunk.current.topRight
            let brtl = brChunk.current.topLeft
            
            let tl = tiles[1][1]
            let tr = tiles[chunkWidth1-1][1]
            let bl = tiles[1][chunkHeight1-1]
            let br = tiles[chunkWidth1-1][chunkHeight1-1]
            
            let tll = tiles[0][0]
            let trl = tiles[chunkWidth1][0]
            let bll = tiles[0][chunkHeight1]
            let brl = tiles[chunkWidth1][chunkHeight1]
            
            //MARK: Borders
            // top
            if changed.top {
                var changed = false
                for i in 1...chunkWidth2 {
                    var count = 0
                    //if tChunk.bl != 0 {
                    for k in -1...1 {
                        let tile = tChunk.tiles[i+k][chunkHeight1]
                        if tile {
                            count++
                        }
                    }
                    //} if tl != 0 {
                    count = count + Int(tiles[i-1][0]) + Int(tiles[i+1][0])
                    //} if lifes != 0 {
                    for k in -1...1 {
                        let tile = tiles[i+k][1]
                        if tile {
                            count++
                        }
                    }
                    //}
                    
                    let life = tiles[i][0]
                    let result = decideTheFate(life, count: count)
                    if result {
                        if i == 1 {
                            tChunk.changedNew.bottomLeft = true
                            changedNew.topLeft = true
                            changedNew.left = true
                        } else if i == chunkWidth2 {
                            tChunk.changedNew.bottomRight = true
                            changedNew.topRight = true
                            changedNew.right = true
                        }
                        changed = true
                        if life {
                            currentNew.top--
                        } else {
                            currentNew.top++
                        }
                        setPixel(!life, x: i, y: 0)
                        tilesNew[i][0] = !life
                    }
                }
                if changed {
                    changes = true
                    topChangedNew()
                }
            }
            
            // bottom
            if changed.bottom {
                var changed = false
                for i in 1...chunkWidth2 {
                    var count = 0
                    //if bChunk.tl != 0 {
                    for k in -1...1 {
                        let tile = bChunk.tiles[i+k][0]
                        if tile {
                            count++
                        }
                    }
                    //} if bl != 0 {
                    count = count + Int(tiles[i-1][chunkHeight1]) + Int(tiles[i+1][chunkHeight1])
                    //} if lifes != 0 {
                    for k in -1...1 {
                        let tile = tiles[i+k][chunkHeight1-1]
                        if tile {
                            count++
                        }
                    }
                    //}
                    
                    let life = tiles[i][chunkHeight1]
                    let result = decideTheFate(life, count: count)
                    if result {
                        if i == 1 {
                            bChunk.changedNew.topLeft = true
                            changedNew.bottomLeft = true
                            changedNew.left = true
                        } else if i == chunkWidth2 {
                            bChunk.changedNew.topRight = true
                            changedNew.bottomRight = true
                            changedNew.right = true
                        }
                        changed = true
                        if life {
                            currentNew.bottom--
                        } else {
                            currentNew.bottom++
                        }
                        setPixel(!life, x: i, y: chunkHeight1)
                        tilesNew[i][chunkHeight1] = !life
                    }
                }
                if changed {
                    changes = true
                    bottomChangedNew()
                }
            }
            
            
            
            
            // left
            if changed.left {
                var changed = false
                for i in 1...chunkHeight2 {
                    var count = 0
                    //if lChunk.rl != 0 {
                    for k in -1...1 {
                        let tile = lChunk.tiles[chunkWidth1][i+k]
                        if tile {
                            count++
                        }
                    }
                    //} if tl != 0 {
                    count = count + Int(tiles[0][i-1]) + Int(tiles[0][i+1])
                    //} if lifes != 0 {
                    for k in -1...1 {
                        let tile = tiles[1][i+k]
                        if tile {
                            count++
                        }
                    }
                    //}
                    
                    let life = tiles[0][i]
                    let result = decideTheFate(life, count: count)
                    if result {
                        if i == 1 {
                            lChunk.changedNew.topRight = true
                            changedNew.topLeft = true
                            changedNew.top = true
                        } else if i == chunkHeight2 {
                            lChunk.changedNew.bottomRight = true
                            changedNew.bottomLeft = true
                            changedNew.bottom = true
                        }
                        changed = true
                        if life {
                            currentNew.left--
                        } else {
                            currentNew.left++
                        }
                        setPixel(!life, x: 0, y: i)
                        tilesNew[0][i] = !life
                    }
                }
                if changed {
                    changes = true
                    leftChangedNew()
                }
            }
            
            
            // right
            if changed.right {
                var changed = false
                for j in 1...chunkHeight2 {
                    var count = 0
                    //if rChunk.ll != 0 {
                    for k in -1...1 {
                        let tile = rChunk.tiles[0][j+k]
                        if tile {
                            count++
                        }
                    }
                    //} if rl != 0 {
                    count = count + Int(tiles[chunkWidth1][j-1]) + Int(tiles[chunkWidth1][j+1])
                    //} if lifes != 0 {
                    for k in -1...1 {
                        let tile = tiles[chunkWidth1-1][j+k]
                        if tile {
                            count++
                        }
                    }
                    //}
                    
                    let life = tiles[chunkWidth1][j]
                    let result = decideTheFate(life, count: count)
                    if result {
                        if j == 1 {
                            rChunk.changedNew.topLeft = true
                            changedNew.topRight = true
                            changedNew.top = true
                        } else if j == chunkHeight2 {
                            rChunk.changedNew.bottomLeft = true
                            changedNew.bottomRight = true
                            changedNew.bottom = true
                        }
                        changed = true
                        if life {
                            currentNew.right--
                        } else {
                            currentNew.right++
                        }
                        setPixel(!life, x: chunkWidth1, y: j)
                        tilesNew[chunkWidth1][j] = !life
                    }
                }
                if changed {
                    changes = true
                    rightChangedNew()
                }
            }
            //MARK: Corners
            
            // top left
            if changed.topLeft {
                var changed = false
                let tlc = Int(tiles[1][1]) + Int(tiles[0][1]) + Int(tiles[1][0]) + Int(tlbr) + Int(tChunk.tiles[0][chunkHeight1]) + Int(tChunk.tiles[1][chunkHeight1]) + Int(lChunk.tiles[chunkWidth1][0]) + Int(lChunk.tiles[chunkWidth1][1])
                
                    let result = decideTheFate(tll, count: tlc)
                    if result {
                        changes = true
                        topLeftChangedNew()
                        currentNew.topLeft = !tll
                        setPixel(!tll, x: 0, y: 0)
                        tilesNew[0][0] = !tll
                    }
            }
            
            // top right
            if changed.topRight {
                let trc = Int(tiles[chunkWidth1-1][1]) + Int(tiles[chunkWidth1][1]) + Int(tiles[chunkWidth1-1][0]) + Int(trbl) + Int(tChunk.tiles[chunkWidth1][chunkHeight1]) + Int(tChunk.tiles[chunkWidth1-1][chunkHeight1]) + Int(rChunk.tiles[0][0]) + Int(rChunk.tiles[0][1])
                
                    let result = decideTheFate(trl, count: trc)
                    if result {
                        changes = true
                        topRightChangedNew()
                        currentNew.topRight = !trl
                        setPixel(!trl, x: chunkWidth1, y: 0)
                        tilesNew[chunkWidth1][0] = !trl
                    }
            }
            
            // bottom left
            if changed.bottomLeft {
                let blc = Int(tiles[1][chunkHeight1-1]) + Int(tiles[0][chunkHeight1-1]) + Int(tiles[1][chunkHeight1]) + Int(bltr) + Int(bChunk.tiles[0][0]) + Int(bChunk.tiles[1][0]) + Int(lChunk.tiles[chunkWidth1][chunkHeight1]) + Int(lChunk.tiles[chunkWidth1][chunkHeight1-1])
                
                    let result = decideTheFate(bll, count: blc)
                    if result {
                        changes = true
                        bottomLeftChangedNew()
                        currentNew.bottomLeft = !bll
                        setPixel(!bll, x: 0, y: chunkHeight1)
                        tilesNew[0][chunkHeight1] = !bll
                    }
            }
            
            // bottom right
            if changed.bottomRight {
                let asd = Int(bChunk.tiles[chunkWidth1-1][0]) + Int(rChunk.tiles[0][chunkHeight1]) + Int(rChunk.tiles[0][chunkHeight1-1])
                let brc = Int(tiles[chunkWidth1-1][chunkHeight1-1]) + Int(tiles[chunkWidth1][chunkHeight1-1]) + Int(tiles[chunkWidth1-1][chunkHeight1]) + Int(brtl) + Int(bChunk.tiles[chunkWidth1][0]) + asd
                
                    let result = decideTheFate(brl, count: brc)
                    if result {
                        changes = true
                        bottomRightChangedNew()
                        currentNew.bottomRight = !brl
                        setPixel(!brl, x: chunkWidth1, y: chunkHeight1)
                        tilesNew[chunkWidth1][chunkHeight1] = !brl
                    }
            }
            
            
            //MARK: Center
            var changedCenter = false
            for i in 1...chunkWidth2 {
                for j in 1...chunkHeight2 {
                    let count = countNeighbors(i, y: j)
                    let life = tiles[i][j]
                    let result = decideTheFate(life, count: count)
                    if result {
                        changedCenter = true
                        if life {
                            currentNew.center--
                        } else {
                            currentNew.center++
                        }
                        setPixel(!life, x: i, y: j)
                        tilesNew[i][j] = !life
                    }
                }
            }
            if changedCenter {
                changes = true
                changedNew.setAll(true)
            }
        }
    }
    func apply() {
        if changes {
            tiles = tilesNew
            current.merge(currentNew)
            draw()
        } else {
            active = activeNew
            activeNew = false
        }
        if active {
            changed.merge(changedNew)
            changedNew.setAll(false)
        }
    }
    // MARK: Game rules
    func countNeighbors(x: Int, y: Int) -> Int {
        var count = 0
        for k in -1...1 {
            for l in -1...1 {
                if !(k == 0 && l == 0) {
                    let tile = tiles[x+k][y+l]
                    if tile {
                        count++
                    }
                }
            }
        }
        return count
    }
    func decideTheFate(life: Bool, count: Int) -> Bool {
        if life {
            if count != 2 && count != 3 {
                return true
            }
        }
        else {
            if count == 3 {
                return true
            }
        }
        return false
    }
    
    // MARK: Graphics
    func redraw() {
        if lifeColor == 0 {
            for i: Int in 0...chunkWidth - 1 {
                for j: Int in 0...chunkHeight - 1 {
                    let offset = 4*((Int(chunkWidth) * j) + i)
                    let type = tiles[i][j]
                    
                    let even: Bool = (i & 1 + j & 1) == 1
                    let color: UInt8 = even ? 255 : 225
                    if type {
                        dataType[offset+1] = color
                        dataType[offset+2] = color
                        dataType[offset+3] = color
                    }
                    else {
                        dataType[offset+1] = UInt8(arc4random_uniform(30))
                        dataType[offset+2] = UInt8(arc4random_uniform(30))
                        dataType[offset+3] = UInt8(arc4random_uniform(30))
                    }
                }
            }
        } else if lifeColor == 1 {
            for i: Int in 0...chunkWidth - 1 {
                for j: Int in 0...chunkHeight - 1 {
                    let offset = 4*((Int(chunkWidth) * j) + i)
                    let type = tiles[i][j]
                    
                    let even: Bool = (i & 1 + j & 1) == 1
                    if type {
                        dataType[offset+1] = even ? eventSecondRed : eventRed
                        dataType[offset+2] = even ? eventSecondGreen : eventGreen
                        dataType[offset+3] = even ? eventSecondBlue : eventBlue
                    }
                    else {
                        dataType[offset+1] = UInt8(arc4random_uniform(30))
                        dataType[offset+2] = UInt8(arc4random_uniform(30))
                        dataType[offset+3] = UInt8(arc4random_uniform(30))
                    }
                }
            }
        } else if lifeColor == 2 {
            for i: Int in 0...chunkWidth - 1 {
                for j: Int in 0...chunkHeight - 1 {
                    let offset = 4*((Int(chunkWidth) * j) + i)
                    let type = tiles[i][j]
                    if type {
                        dataType[offset+1] = 255
                        dataType[offset+2] = UInt8(arc4random_uniform(255))
                        dataType[offset+3] = UInt8(arc4random_uniform(255))
                    }
                    else {
                        dataType[offset+1] = UInt8(arc4random_uniform(30))
                        dataType[offset+2] = UInt8(arc4random_uniform(30))
                        dataType[offset+3] = UInt8(arc4random_uniform(30))
                    }
                }
            }
        }
        draw()
    }
    
    func draw() {
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.PremultipliedFirst.rawValue)
        let context = CGBitmapContextCreate(bitmapData, UInt(chunkWidth), UInt(chunkHeight), CUnsignedLong(8),  CUnsignedLong(bitmapBytesPerRow), colorSpace, bitmapInfo)
        CGContextSetShouldAntialias(context, false)
        let imageRef = CGBitmapContextCreateImage(context)
        
        view.image = UIImage(CGImage: imageRef)
    }
    
    func firstDraw() {
        for i: Int in 0...chunkWidth - 1 {
            for j: Int in 0...chunkHeight - 1 {
                let offset = 4*((Int(chunkWidth) * j) + i)
                
                let even: Bool = (i & 1 + j & 1) == 1
                
                dataType[offset] = 255
                dataType[offset+1] = UInt8(arc4random_uniform(30))
                dataType[offset+2] = UInt8(arc4random_uniform(30))
                dataType[offset+3] = UInt8(arc4random_uniform(30))
            }
        }
        draw()
    }
    // MARK: Editor
    func setTile(type: Bool, x: Int, y: Int) {
        tiles[x][y] = type
        active = true
        setPixel(type, x: x, y: y)
        let n = type ? 1 : -1
        if x == 0 && y == 0 {
            current.topLeft = type
            topLeftChanged()
        } else if x == chunkWidth1 && y == 0 {
            current.topRight = type
            topRightChanged()
        } else if x == 0 && y == chunkHeight1 {
            current.bottomLeft = type
            bottomLeftChanged()
        } else if x == chunkWidth1 && y == chunkHeight1 {
            current.bottomRight = type
            bottomRightChanged()
        } else if y == 0 {
            current.top += n
            topChanged()
        } else if y == chunkHeight1 {
            current.bottom += n
            bottomChanged()
        } else if x == 0 {
            current.left += n
            leftChanged()
        } else if x == chunkWidth1 {
            current.right += n
            rightChanged()
        } else {
            current.center += n
            centerChanged()
        }
    }
    
    func setPixel(type: Bool, x: Int, y: Int) {
        let offset = 4*((Int(chunkWidth) * y) + x)
        if type {
            switch lifeColor {
            case 0:
                let even: Bool = (x + y) & 1 == 1
                let color: UInt8 = even ? 255 : 225
                dataType[offset+1] = color
                dataType[offset+2] = color
                dataType[offset+3] = color
            case 1:
                let even: Bool = (x + y) & 1 == 1
                dataType[offset+1] = even ? eventSecondRed : eventRed
                dataType[offset+2] = even ? eventSecondGreen : eventGreen
                dataType[offset+3] = even ? eventSecondBlue : eventBlue
            case 2:
                dataType[offset+1] = 255
                dataType[offset+2] = UInt8(arc4random_uniform(255))
                dataType[offset+3] = UInt8(arc4random_uniform(255))
            default:
                break
            }
        }
        else {
            dataType[offset+1] = UInt8(arc4random_uniform(30))
            dataType[offset+2] = UInt8(arc4random_uniform(30))
            dataType[offset+3] = UInt8(arc4random_uniform(30))
        }
    }
    func clear() {
        active = false
        activeNew = false
        changes = false
        changed.setAll(false)
        if current.nonEmpty() {
            current.clear()
            self.tiles = [[Bool]](count: chunkWidth, repeatedValue: [Bool](count: chunkHeight, repeatedValue: false))
            redraw()
        }
    }
    // MARK: Defines
    func topLeftChunk() -> Chunk {
        return map.chunks[x == 0 ? map.width1 : x - 1][y == 0 ? map.height1 : y - 1]
    }
    func topChunk() -> Chunk {
        return map.chunks[x][y == 0 ? map.height1 : y-1]
    }
    func topRightChunk() -> Chunk {
        return map.chunks[x == map.width1 ? 0 : x + 1][y == 0 ? map.height1 : y - 1]
    }
    func leftChunk() -> Chunk {
        return map.chunks[x == 0 ? map.width1 : x-1][y]
    }
    func rightChunk() -> Chunk {
        return map.chunks[x == map.width1 ? 0 : x+1][y]
    }
    func bottomLeftChunk() -> Chunk {
        return map.chunks[x == 0 ? map.width1 : x - 1][y == map.height1 ? 0 : y + 1]
    }
    func bottomChunk() -> Chunk {
        return map.chunks[x][y == map.width1 ? 0 : y+1]
    }
    func bottomRightChunk() -> Chunk {
        return map.chunks[x == map.width1 ? 0 : x + 1][y == map.height1 ? 0 : y + 1]
    }
    func topLeftChanged() {
        changed.center = true
        changed.topLeft = true
        changed.top = true
        changed.left = true
        let chunk1 = topChunk()
        let chunk2 = leftChunk()
        let chunk3 = topLeftChunk()
        chunk1.active = true
        chunk2.active = true
        chunk3.active = true
        chunk1.changed.bottomLeft = true
        chunk2.changed.topRight = true
        chunk3.changed.bottomRight = true
        chunk1.changed.bottom = true
        chunk2.changed.right = true
    }
    func topRightChanged() {
        changed.center = true
        changed.topRight = true
        changed.top = true
        changed.right = true
        let chunk1 = topChunk()
        let chunk2 = rightChunk()
        let chunk3 = topRightChunk()
        chunk1.active = true
        chunk2.active = true
        chunk3.active = true
        chunk1.changed.bottomRight = true
        chunk2.changed.topLeft = true
        chunk3.changed.bottomLeft = true
        chunk1.changed.bottom = true
        chunk2.changed.left = true
    }
    func bottomLeftChanged() {
        changed.center = true
        changed.bottomLeft = true
        changed.bottom = true
        changed.left = true
        let chunk1 = bottomChunk()
        let chunk2 = leftChunk()
        let chunk3 = bottomLeftChunk()
        chunk1.active = true
        chunk2.active = true
        chunk3.active = true
        chunk1.changed.topLeft = true
        chunk2.changed.bottomRight = true
        chunk3.changed.topRight = true
        chunk1.changed.top = true
        chunk2.changed.right = true
    }
    func bottomRightChanged() {
        changed.center = true
        changed.bottomRight = true
        changed.bottom = true
        changed.right = true
        let chunk1 = bottomChunk()
        let chunk2 = rightChunk()
        let chunk3 = bottomRightChunk()
        chunk1.active = true
        chunk2.active = true
        chunk3.active = true
        chunk1.changed.topRight = true
        chunk2.changed.bottomLeft = true
        chunk3.changed.topLeft = true
        chunk1.changed.top = true
        chunk2.changed.left = true
    }
    func topChanged() {
        changed.center = true
        changed.top = true
        changed.topLeft = true
        changed.topRight = true
        let chunk = topChunk()
        chunk.active = true
        chunk.changed.bottom = true
        chunk.changed.bottomLeft = true
        chunk.changed.bottomRight = true
    }
    func bottomChanged() {
        changed.center = true
        changed.bottom = true
        changed.bottomLeft = true
        changed.bottomRight = true
        let chunk = bottomChunk()
        chunk.active = true
        chunk.changed.top = true
        chunk.changed.topLeft = true
        chunk.changed.topRight = true
    }
    func leftChanged() {
        changed.center = true
        changed.left = true
        changed.topLeft = true
        changed.bottomLeft = true
        let chunk = leftChunk()
        chunk.active = true
        chunk.changed.right = true
        chunk.changed.topRight = true
        chunk.changed.bottomRight = true
    }
    func rightChanged() {
        changed.center = true
        changed.right = true
        changed.topRight = true
        changed.bottomRight = true
        let chunk = rightChunk()
        chunk.active = true
        chunk.changed.left = true
        chunk.changed.topLeft = true
        chunk.changed.bottomLeft = true
    }
    func centerChanged() {
        changed.setAll(true)
    }
    
    func topLeftChangedNew() {
        changedNew.center = true
        changedNew.topLeft = true
        changedNew.top = true
        changedNew.left = true
        let chunk1 = topChunk()
        let chunk2 = leftChunk()
        let chunk3 = topLeftChunk()
        chunk1.activeNew = true
        chunk2.activeNew = true
        chunk3.activeNew = true
        chunk1.changedNew.bottomLeft = true
        chunk2.changedNew.topRight = true
        chunk3.changedNew.bottomRight = true
        chunk1.changedNew.bottom = true
        chunk2.changedNew.right = true
    }
    func topRightChangedNew() {
        changedNew.center = true
        changedNew.topRight = true
        changedNew.top = true
        changedNew.right = true
        let chunk1 = topChunk()
        let chunk2 = rightChunk()
        let chunk3 = topRightChunk()
        chunk1.activeNew = true
        chunk2.activeNew = true
        chunk3.activeNew = true
        chunk1.changedNew.bottomRight = true
        chunk2.changedNew.topLeft = true
        chunk3.changedNew.bottomLeft = true
        chunk1.changedNew.bottom = true
        chunk2.changedNew.left = true
    }
    func bottomLeftChangedNew() {
        changedNew.center = true
        changedNew.bottomLeft = true
        changedNew.bottom = true
        changedNew.left = true
        let chunk1 = bottomChunk()
        let chunk2 = leftChunk()
        let chunk3 = bottomLeftChunk()
        chunk1.activeNew = true
        chunk2.activeNew = true
        chunk3.activeNew = true
        chunk1.changedNew.topLeft = true
        chunk2.changedNew.bottomRight = true
        chunk3.changedNew.topRight = true
        chunk1.changedNew.top = true
        chunk2.changedNew.right = true
    }
    func bottomRightChangedNew() {
        changedNew.center = true
        changedNew.bottomRight = true
        changedNew.bottom = true
        changedNew.right = true
        let chunk1 = bottomChunk()
        let chunk2 = rightChunk()
        let chunk3 = bottomRightChunk()
        chunk1.activeNew = true
        chunk2.activeNew = true
        chunk3.activeNew = true
        chunk1.changedNew.topRight = true
        chunk2.changedNew.bottomLeft = true
        chunk3.changedNew.topLeft = true
        chunk1.changedNew.top = true
        chunk2.changedNew.left = true
    }
    func topChangedNew() {
        changedNew.center = true
        changedNew.top = true
        changedNew.topLeft = true
        changedNew.topRight = true
        let chunk = topChunk()
        chunk.activeNew = true
        chunk.changedNew.bottom = true
        chunk.changedNew.bottomLeft = true
        chunk.changedNew.bottomRight = true
    }
    func bottomChangedNew() {
        changedNew.center = true
        changedNew.bottom = true
        changedNew.bottomLeft = true
        changedNew.bottomRight = true
        let chunk = bottomChunk()
        chunk.activeNew = true
        chunk.changedNew.top = true
        chunk.changedNew.topLeft = true
        chunk.changedNew.topRight = true
    }
    func leftChangedNew() {
        changedNew.center = true
        changedNew.left = true
        changedNew.topLeft = true
        changedNew.bottomLeft = true
        let chunk = leftChunk()
        chunk.activeNew = true
        chunk.changedNew.right = true
        chunk.changedNew.topRight = true
        chunk.changedNew.bottomRight = true
    }
    func rightChangedNew() {
        changedNew.center = true
        changedNew.right = true
        changedNew.topRight = true
        changedNew.bottomRight = true
        let chunk = rightChunk()
        chunk.activeNew = true
        chunk.changedNew.left = true
        chunk.changedNew.topLeft = true
        chunk.changedNew.bottomLeft = true
    }
    func centerChangedNew() {
        changedNew.setAll(true)
    }
}

class ChunkLifes {
    var center = 0
    var top = 0
    var bottom = 0
    var left = 0
    var right = 0
    var topLeft = false
    var topRight = false
    var bottomLeft = false
    var bottomRight = false
    func clear() {
        center = 0
        top = 0
        bottom = 0
        left = 0
        right = 0
        topLeft = false
        topRight = false
        bottomLeft = false
        bottomRight = false
    }
    func merge(original: ChunkLifes) {
        center = original.center
        top = original.top
        bottom = original.bottom
        left = original.left
        right = original.right
        topLeft = original.topLeft
        topRight = original.topRight
        bottomLeft = original.bottomLeft
        bottomRight = original.bottomRight
    }
    func nonEmpty() -> Bool {
        let a = center + top + bottom + left + right + Int(topLeft) + Int(topRight) + Int(bottomLeft) + Int(bottomRight)
        return a != 0
    }
    func sum() -> Int {
        let a = center + top + bottom + left + right + Int(topLeft) + Int(topRight) + Int(bottomLeft) + Int(bottomRight)
        return a
    }
}

class ChunkChanges {
    var center = false
    var top = false
    var bottom = false
    var left = false
    var right = false
    var topLeft = false
    var topRight = false
    var bottomLeft = false
    var bottomRight = false
    func setAll(status: Bool) {
        center = status
        top = status
        bottom = status
        left = status
        right = status
        topLeft = status
        topRight = status
        bottomLeft = status
        bottomRight = status
    }
    func merge(original: ChunkChanges) {
        center = original.center
        top = original.top
        bottom = original.bottom
        left = original.left
        right = original.right
        topLeft = original.topLeft
        topRight = original.topRight
        bottomLeft = original.bottomLeft
        bottomRight = original.bottomRight
    }
    func nonEmpty() -> Bool {
        return center || top || bottom || left || right || topLeft || topRight || bottomLeft || bottomRight
    }
}

func getCenter(pos1: CGPoint, pos2: CGPoint) -> CGPoint {
    let dx = pos2.x - pos1.x
    let dy = pos2.y - pos1.y
    return CGPoint(x: pos1.x + dx, y: pos1.y + dy)
}

func findEventColor() {
    let date = NSDate()
    let calendar = NSCalendar.currentCalendar()
    let components = calendar.components(.Month | .Day, fromDate: date)
    let month = components.month
    let day = components.day
    if month == 12 || month < 3 {
        eventRed = 100
        eventGreen = 150
        eventBlue = 255
        event = "Winter"
    } else if month < 6 {
        eventRed = 0
        eventGreen = 180
        eventBlue = 0
        eventSecondRed = 240
        eventSecondGreen = 0
        eventSecondBlue = 0
        event = "Sprting"
    } else if month < 9 {
        eventRed = 80
        eventGreen = 190
        eventBlue = 80
        eventSecondRed = 80
        eventSecondGreen = 230
        eventSecondBlue = 80
        event = "Summer"
    } else if month < 12 {
        eventRed = 140
        eventGreen = 90
        eventBlue = 40
        eventSecondRed = 0
        eventSecondGreen = 180
        eventSecondBlue = 0
        event = "Autumn"
    }
    switch month {
    case 1:
        if day <= 16 { // New year
            eventRed = 230
            eventGreen = 0
            eventBlue = 0
            eventSecondRed = 230
            eventSecondGreen = 230
            eventSecondBlue = 230
            event = "New Year"
        }
    case 2:
        if day >= 10 && day <= 18 { // St. Valentine's Day
            eventRed = 255
            eventGreen = 0
            eventBlue = 0
            eventSecondRed = 200
            eventSecondGreen = 0
            eventSecondBlue = 0
            event = "St. Valentine's Day"
        }
    case 3:
        if day >= 15 && day < 19 { // St. Patrick's day
            eventRed = 80
            eventGreen = 190
            eventBlue = 80
            eventSecondRed = 235
            eventSecondGreen = 235
            eventSecondBlue = 235
            event = "St. Patrick's day"
        }
    case 6:
        if day >= 17 { // Ramadan
            eventRed = 255
            eventGreen = 147
            eventBlue = 0
            eventSecondRed = 230
            eventSecondGreen = 230
            eventSecondBlue = 0
            event = "Ramadan"
        }
    case 7:
        if day <= 16 { // Ramadan
            eventRed = 255
            eventGreen = 147
            eventBlue = 0
            eventSecondRed = 230
            eventSecondGreen = 230
            eventSecondBlue = 0
            event = "Ramadan"
        }
    case 10:
        if day >= 28 { // Halloween
            eventRed = 255
            eventGreen = 255
            eventBlue = 140
            eventSecondRed = 250
            eventSecondGreen = 150
            eventSecondBlue = 0
            event = "Halloween"
        }
    case 11:
        if day <= 4 { // Halloween
            eventRed = 255
            eventGreen = 255
            eventBlue = 140
            eventSecondRed = 250
            eventSecondGreen = 150
            eventSecondBlue = 0
            event = "Halloween"
        }
    case 12:
        if day >= 28 { // New year
            eventRed = 230
            eventGreen = 0
            eventBlue = 0
            eventSecondRed = 230
            eventSecondGreen = 230
            eventSecondBlue = 230
            event = "New year"
        }
    default:
        break
    }
}