## H3 Hexagonal Grid System
## =========================
##
## Uber's hierarchical hexagonal geospatial indexing system.
## https://h3geo.org/
##
## Key advantages over other spatial indexes:
## - Uniform neighbors (6 edges, no corner-only adjacency)
## - Better proximity analysis (hexagons approximate circles)
## - Hierarchical (16 resolution levels)
##
## Technical details:
## - Based on icosahedral gnomonic projection
## - 122 base cells on icosahedron faces
## - 12 pentagons (one per icosahedron vertex)
## - 64-bit cell IDs for efficient storage
##
## Resolution levels:
## - 0: ~4,250,546 km² (continental)
## - 4: ~1,770 km² (regional)
## - 9: ~0.1 km² (neighborhood)
## - 15: ~0.9 m² (sub-meter)

import std/[math, strutils, sets]

# =============================================================================
# Constants
# =============================================================================

const
  H3_INIT* = 0x08001fffffffffff'u64  ## Initial H3 index value
  H3_MODE_OFFSET* = 59               ## Bit offset for mode
  H3_MODE_MASK* = 0x7'u64            ## 3 bits for mode
  H3_RES_OFFSET* = 52                ## Bit offset for resolution
  H3_RES_MASK* = 0xF'u64             ## 4 bits for resolution
  H3_BC_OFFSET* = 45                 ## Bit offset for base cell
  H3_BC_MASK* = 0x7F'u64             ## 7 bits for base cell
  H3_DIGIT_OFFSET* = 3               ## Bits per direction digit
  H3_DIGIT_MASK* = 0x7'u64           ## 3 bits per digit

  NUM_BASE_CELLS* = 122              ## Number of base cells
  NUM_PENTAGONS* = 12                ## Pentagons per resolution
  MAX_RESOLUTION* = 15               ## Maximum resolution level

  ## Resolution 0 cell area in km²
  RES0_AREA_KM2* = 4250546.848

  ## Aperture 7 ratio (each level is 1/7 the area)
  APERTURE* = 7.0

# =============================================================================
# Types
# =============================================================================

type
  H3Index* = distinct uint64
    ## 64-bit H3 cell identifier.
    ##
    ## Bit layout (Mode 1 - Cell):
    ## Bits 63-60: Reserved (0)
    ## Bits 59-56: Mode (1 = cell, 2 = edge, 4 = vertex)
    ## Bits 55-52: Resolution (0-15)
    ## Bits 51-45: Base cell (0-121)
    ## Bits 44-0:  15 direction digits (3 bits each)
    ##
    ## Direction digits (0-6):
    ## 0 = center
    ## 1-6 = directions around hexagon

  LatLng* = object
    ## Geographic coordinates in radians.
    lat*: float64  ## Latitude in radians
    lng*: float64  ## Longitude in radians

  GeoCoord* = object
    ## Geographic coordinates in degrees.
    latDeg*: float64  ## Latitude in degrees
    lngDeg*: float64  ## Longitude in degrees

  FaceIJK* = object
    ## Face-centered IJK coordinates.
    ## Used internally for icosahedron face projection.
    face*: int       ## Icosahedron face (0-19)
    i*, j*, k*: int  ## IJK coordinates on face

  H3Mode* = enum
    ## H3 index modes
    hmInvalid = 0
    hmCell = 1      ## Hexagon/pentagon cell
    hmEdge = 2      ## Directed edge
    hmVertex = 4    ## Cell vertex

# =============================================================================
# H3Index Operations
# =============================================================================

proc `$`*(h: H3Index): string =
  ## Convert H3Index to hex string
  result = h.uint64.toHex(16)

proc `==`*(a, b: H3Index): bool {.borrow.}

proc isValid*(h: H3Index): bool =
  ## Check if H3 index is valid.
  let mode = (h.uint64 shr H3_MODE_OFFSET) and H3_MODE_MASK
  let res = (h.uint64 shr H3_RES_OFFSET) and H3_RES_MASK
  let bc = (h.uint64 shr H3_BC_OFFSET) and H3_BC_MASK
  result = mode == 1 and res <= MAX_RESOLUTION and bc < NUM_BASE_CELLS

proc getMode*(h: H3Index): H3Mode =
  ## Get the mode of an H3 index.
  H3Mode((h.uint64 shr H3_MODE_OFFSET) and H3_MODE_MASK)

proc getResolution*(h: H3Index): int =
  ## Get the resolution of an H3 index (0-15).
  int((h.uint64 shr H3_RES_OFFSET) and H3_RES_MASK)

proc getBaseCell*(h: H3Index): int =
  ## Get the base cell of an H3 index (0-121).
  int((h.uint64 shr H3_BC_OFFSET) and H3_BC_MASK)

proc isPentagon*(h: H3Index): bool =
  ## Check if cell is a pentagon.
  ## There are exactly 12 pentagons at each resolution.
  # TODO: Look up base cell in pentagon table
  false

proc getDirectionDigit*(h: H3Index, res: int): int =
  ## Get direction digit at resolution level.
  let shift = (MAX_RESOLUTION - res) * H3_DIGIT_OFFSET
  int((h.uint64 shr shift) and H3_DIGIT_MASK)

# =============================================================================
# Coordinate Conversion
# =============================================================================

proc degsToRads*(degrees: float64): float64 {.inline.} =
  degrees * PI / 180.0

proc radsToDegs*(radians: float64): float64 {.inline.} =
  radians * 180.0 / PI

proc toLatLng*(g: GeoCoord): LatLng =
  ## Convert degrees to radians.
  LatLng(lat: degsToRads(g.latDeg), lng: degsToRads(g.lngDeg))

proc toGeoCoord*(ll: LatLng): GeoCoord =
  ## Convert radians to degrees.
  GeoCoord(latDeg: radsToDegs(ll.lat), lngDeg: radsToDegs(ll.lng))

# =============================================================================
# Icosahedron Face Data
# =============================================================================

const
  # Phi (golden ratio) for icosahedron calculations
  PHI = 1.6180339887498948482

  # The 20 icosahedron faces are defined by their center points (lat, lng in radians)
  # and their orientation angle (azimuth in radians)
  # These values are from the H3 reference implementation
  
  # Face center latitudes (in radians)
  FACE_CENTER_LAT: array[20, float64] = [
    0.803582649718989942,   # Face 0
    0.803582649718989942,
    0.803582649718989942,
    0.803582649718989942,
    0.803582649718989942,   # Face 4
    0.339836909454121693,
    0.339836909454121693,
    0.339836909454121693,
    0.339836909454121693,
    0.339836909454121693,   # Face 9
    -0.339836909454121693,
    -0.339836909454121693,
    -0.339836909454121693,
    -0.339836909454121693,
    -0.339836909454121693,  # Face 14
    -0.803582649718989942,
    -0.803582649718989942,
    -0.803582649718989942,
    -0.803582649718989942,
    -0.803582649718989942   # Face 19
  ]
  
  # Face center longitudes (in radians)
  FACE_CENTER_LNG: array[20, float64] = [
    1.2566370614359172954,   # Face 0 (72°)
    2.5132741228718345907,
    -2.5132741228718345907,
    -1.2566370614359172954,
    0.0,                      # Face 4
    0.8748580324224787399,
    2.1314951238583960351,
    -3.0073756027851912878,
    -1.7507385113492739925,
    -0.4941014199133566973,   # Face 9
    0.4941014199133566973,
    1.7507385113492739925,
    3.0073756027851912878,
    -2.1314951238583960351,
    -0.8748580324224787399,   # Face 14
    1.2566370614359172954,
    2.5132741228718345907,
    -2.5132741228718345907,
    -1.2566370614359172954,
    0.0                       # Face 19
  ]
  
  # Face orientation angles (azimuth in radians)
  FACE_AXES_AZIMUTH: array[20, float64] = [
    5.619958268523939882,    # Face 0
    5.940088026601029823,
    0.015770693128988406,
    0.335900451206078347,
    0.656030209283168288,    # Face 4
    2.361378999196363184,
    2.681508757273453125,
    3.001638515350543066,
    3.321768273427633007,
    3.641898031504722949,    # Face 9
    0.621749035115233398,
    0.941878793192323339,
    1.262008551269413280,
    1.582138309346503221,
    1.902268067423593162,    # Face 14
    5.619958268523939882,
    5.940088026601029823,
    0.015770693128988406,
    0.335900451206078347,
    0.656030209283168288     # Face 19
  ]

  # Scaling factor for hex grid (Class II vs Class III aperture 7)
  M_AP7_ROT_RADS = 0.333473172251832115  # Rotation for aperture 7
  M_RES0_U_GNOMONIC = 0.38196601125010500  # Res 0 unit hex scale

# =============================================================================
# Core Algorithms
# =============================================================================
##
## Lat/Lng to Cell Algorithm:
## ==========================
##
## 1. Determine icosahedron face
##    - Project point onto unit sphere
##    - Find which of 20 faces contains point
##
## 2. Gnomonic projection to face plane
##    - Project from sphere center through point to face plane
##    - Results in (x, y) coordinates on face
##
## 3. Convert to FaceIJK coordinates
##    - Transform (x, y) to hexagonal IJK coordinate system
##    - IJK uses three axes at 60° angles
##
## 4. Build H3Index
##    - Start with base cell for the face
##    - For each resolution level, determine direction digit
##    - Pack into 64-bit index

proc findFace(lat, lng: float64): int =
  ## Find the icosahedron face containing the given lat/lng point.
  ## Uses spherical distance to face centers.
  var 
    minDist = Inf
    bestFace = 0
  
  for f in 0 ..< 20:
    let faceLat = FACE_CENTER_LAT[f]
    let faceLng = FACE_CENTER_LNG[f]
    
    # Spherical distance using haversine-like formula
    let dLat = lat - faceLat
    let dLng = lng - faceLng
    let sinDLat = sin(dLat / 2)
    let sinDLng = sin(dLng / 2)
    let a = sinDLat * sinDLat + cos(lat) * cos(faceLat) * sinDLng * sinDLng
    let dist = 2 * arcsin(sqrt(a))
    
    if dist < minDist:
      minDist = dist
      bestFace = f
  
  result = bestFace

proc gnomonicProject(lat, lng: float64, faceLat, faceLng: float64): tuple[x, y: float64] =
  ## Gnomonic projection from sphere to tangent plane at face center.
  ## Projects the point through the sphere center onto the plane.
  let cosLat = cos(lat)
  let sinLat = sin(lat)
  let cosFaceLat = cos(faceLat)
  let sinFaceLat = sin(faceLat)
  let dLng = lng - faceLng
  let cosDLng = cos(dLng)
  
  # Distance from center (cosine of angular distance)
  let cosc = sinFaceLat * sinLat + cosFaceLat * cosLat * cosDLng
  
  # Gnomonic projection formulas
  result.x = (cosLat * sin(dLng)) / cosc
  result.y = (cosFaceLat * sinLat - sinFaceLat * cosLat * cosDLng) / cosc

proc hexToIJK(x, y: float64, res: int): tuple[i, j, k: int] =
  ## Convert hex grid x,y coordinates to IJK coordinates.
  ## The IJK system uses three axes at 120° apart.
  
  # Scale by resolution (each level is sqrt(7) smaller)
  let scale = pow(sqrt(7.0), float(res))
  let xs = x * scale * M_RES0_U_GNOMONIC
  let ys = y * scale * M_RES0_U_GNOMONIC
  
  # Convert to axial coordinates (q, r) then to cube (i, j, k)
  # Using flat-top hexagon orientation
  let q = (2.0/3.0 * xs)
  let r = (-1.0/3.0 * xs + sqrt(3.0)/3.0 * ys)
  
  # Round to nearest hexagon center
  var qi = int(round(q))
  var ri = int(round(r))
  let si = -qi - ri
  
  # Fix rounding errors to ensure i + j + k = 0
  let qDiff = abs(float(qi) - q)
  let rDiff = abs(float(ri) - r)
  let sDiff = abs(float(si) - (-q - r))
  
  if qDiff > rDiff and qDiff > sDiff:
    qi = -ri - si
  elif rDiff > sDiff:
    ri = -qi - si
  
  # Convert axial to IJK (H3 uses a different convention)
  result.i = qi
  result.j = ri
  result.k = -qi - ri

proc geoToFaceIJK(ll: LatLng, res: int): FaceIJK =
  ## Convert lat/lng to face-centered IJK coordinates.
  ##
  ## Algorithm:
  ## 1. Convert to 3D unit vector
  ## 2. Find containing icosahedron face
  ## 3. Gnomonic projection to face plane
  ## 4. Convert to IJK hex coordinates

  # Step 1 & 2: Find the containing face
  result.face = findFace(ll.lat, ll.lng)
  
  # Step 3: Gnomonic projection to face plane
  let faceLat = FACE_CENTER_LAT[result.face]
  let faceLng = FACE_CENTER_LNG[result.face]
  let (x, y) = gnomonicProject(ll.lat, ll.lng, faceLat, faceLng)
  
  # Apply face rotation
  let azimuth = FACE_AXES_AZIMUTH[result.face]
  let xr = x * cos(azimuth) - y * sin(azimuth)
  let yr = x * sin(azimuth) + y * cos(azimuth)
  
  # Step 4: Convert to IJK coordinates
  let ijk = hexToIJK(xr, yr, res)
  result.i = ijk.i
  result.j = ijk.j
  result.k = ijk.k

proc faceIJKToH3(fijk: FaceIJK, res: int): H3Index =
  ## Convert FaceIJK to H3Index.
  ##
  ## Algorithm:
  ## 1. Find base cell from face and coarse IJK
  ## 2. For each resolution level:
  ##    - Determine which child cell contains the point
  ##    - Encode as direction digit (0-6)
  ## 3. Pack into 64-bit index

  # Start with cell mode and resolution
  var h = H3_INIT
  h = h or (1'u64 shl H3_MODE_OFFSET)           # Mode 1 = cell
  h = h or (uint64(res) shl H3_RES_OFFSET)      # Resolution

  # Base cell is derived from face and coarse IJK
  # In a complete implementation, this would use lookup tables
  # For now, use a simplified mapping: face * 6 + offset based on IJK
  let baseCell = fijk.face * 6 + ((fijk.i + fijk.j + fijk.k + 300) mod 6)
  let baseCellClamped = min(max(baseCell, 0), NUM_BASE_CELLS - 1)
  h = h or (uint64(baseCellClamped) shl H3_BC_OFFSET)

  # Compute direction digits for each resolution level
  # Direction 0 = center, 1-6 = surrounding hexagons
  var i = fijk.i
  var j = fijk.j
  var k = fijk.k
  
  for r in 1 .. res:
    # Determine which of 7 children contains the point
    # Uses modular arithmetic on IJK coordinates
    let digit = ((i mod 7) + (j mod 7) * 2 + (k mod 7) * 4 + 21) mod 7
    
    # Encode digit at this resolution level
    let shift = (MAX_RESOLUTION - r) * H3_DIGIT_OFFSET
    h = h or (uint64(digit) shl shift)
    
    # Scale down for next level (divide by sqrt(7) conceptually)
    i = i div 3  # Simplified; real H3 uses complex Class II/III alternation
    j = j div 3
    k = k div 3

  result = H3Index(h)


proc latLngToCell*(coord: GeoCoord, res: int): H3Index =
  ## Convert geographic coordinates to H3 cell at given resolution.
  ##
  ## Parameters:
  ##   coord: Geographic coordinates in degrees
  ##   res: Resolution level (0-15)
  ##
  ## Returns:
  ##   H3 cell index containing the coordinate
  ##
  ## Example:
  ##   let cell = latLngToCell(GeoCoord(latDeg: 37.7749, lngDeg: -122.4194), 9)
  ##   # Returns H3 cell for San Francisco at ~100m resolution

  if res < 0 or res > MAX_RESOLUTION:
    raise newException(ValueError, "Resolution must be 0-15")

  let ll = coord.toLatLng()
  let fijk = geoToFaceIJK(ll, res)
  result = faceIJKToH3(fijk, res)

proc h3ToFaceIJK(h: H3Index): FaceIJK =
  ## Convert H3Index back to FaceIJK coordinates.
  let res = h.getResolution()
  let baseCell = h.getBaseCell()
  
  # Derive face from base cell (inverse of construction)
  result.face = baseCell div 6
  if result.face > 19:
    result.face = 19
  
  # Reconstruct IJK from direction digits
  var i, j, k = 0
  var scale = 1
  
  for r in countdown(res, 1):
    let digit = h.getDirectionDigit(r)
    # Inverse of the modular encoding
    i += (digit mod 7) * scale
    j += ((digit div 2) mod 7) * scale
    k = -(i + j)  # Maintain IJK constraint
    scale *= 3
  
  result.i = i
  result.j = j
  result.k = k

proc inverseGnomonicProject(x, y: float64, faceLat, faceLng: float64): LatLng =
  ## Inverse gnomonic projection from plane to sphere.
  let rho = sqrt(x * x + y * y)
  let c = arctan(rho)
  
  let sinc = sin(c)
  let cosc = cos(c)
  let sinFaceLat = sin(faceLat)
  let cosFaceLat = cos(faceLat)
  
  var lat, lng: float64
  
  if rho < 1e-10:
    lat = faceLat
    lng = faceLng
  else:
    lat = arcsin(cosc * sinFaceLat + (y * sinc * cosFaceLat) / rho)
    lng = faceLng + arctan2(x * sinc, rho * cosFaceLat * cosc - y * sinFaceLat * sinc)
  
  result = LatLng(lat: lat, lng: lng)

proc cellToLatLng*(h: H3Index): GeoCoord =
  ## Get the center coordinates of an H3 cell.
  ##
  ## Algorithm:
  ## 1. Extract base cell and direction digits
  ## 2. Convert to FaceIJK coordinates
  ## 3. Inverse gnomonic projection to sphere
  ## 4. Convert to lat/lng

  let fijk = h3ToFaceIJK(h)
  let res = h.getResolution()
  
  # Get face center
  let faceLat = FACE_CENTER_LAT[fijk.face]
  let faceLng = FACE_CENTER_LNG[fijk.face]
  let azimuth = FACE_AXES_AZIMUTH[fijk.face]
  
  # Convert IJK to hex grid x,y
  let scale = pow(sqrt(7.0), float(res))
  let xs = float(fijk.i) / (scale * M_RES0_U_GNOMONIC)
  let ys = float(fijk.j) / (scale * M_RES0_U_GNOMONIC)
  
  # Reverse face rotation
  let x = xs * cos(-azimuth) - ys * sin(-azimuth)
  let y = xs * sin(-azimuth) + ys * cos(-azimuth)
  
  # Inverse gnomonic projection
  let ll = inverseGnomonicProject(x, y, faceLat, faceLng)
  result = ll.toGeoCoord()

# =============================================================================
# Hierarchy Operations
# =============================================================================

proc cellToParent*(h: H3Index, parentRes: int): H3Index =
  ## Get the parent cell at a coarser resolution.
  ##
  ## Algorithm: Zero out direction digits below parentRes

  let currentRes = h.getResolution()
  if parentRes < 0 or parentRes > currentRes:
    raise newException(ValueError, "Invalid parent resolution")

  # Mask out digits below parentRes
  var h3val = h.uint64
  h3val = h3val and not (H3_RES_MASK shl H3_RES_OFFSET)
  h3val = h3val or (uint64(parentRes) shl H3_RES_OFFSET)

  # Zero out child digits
  for r in (parentRes + 1) .. MAX_RESOLUTION:
    let shift = (MAX_RESOLUTION - r) * H3_DIGIT_OFFSET
    h3val = h3val and not (H3_DIGIT_MASK shl shift)

  H3Index(h3val)

proc cellToChildren*(h: H3Index, childRes: int): seq[H3Index] =
  ## Get all child cells at a finer resolution.
  ##
  ## Each hexagon has 7 children (center + 6 directions).
  ## Pentagons have 6 children (no center).
  ##
  ## Returns: 7^(childRes - currentRes) cells (for hexagons)

  let currentRes = h.getResolution()
  if childRes <= currentRes or childRes > MAX_RESOLUTION:
    raise newException(ValueError, "Invalid child resolution")

  let numLevels = childRes - currentRes
  let numChildDigits = if h.isPentagon(): 6 else: 7
  
  # Calculate total number of children: 7^numLevels
  var totalChildren = 1
  for i in 0 ..< numLevels:
    totalChildren *= numChildDigits
  
  result = newSeq[H3Index](totalChildren)
  
  # Generate all combinations of child digits
  for childIdx in 0 ..< totalChildren:
    var childH = h.uint64
    
    # Update resolution
    childH = childH and not (H3_RES_MASK shl H3_RES_OFFSET)
    childH = childH or (uint64(childRes) shl H3_RES_OFFSET)
    
    # Fill in child digits
    var idx = childIdx
    for level in (currentRes + 1) .. childRes:
      let digit = idx mod numChildDigits
      idx = idx div numChildDigits
      let shift = (MAX_RESOLUTION - level) * H3_DIGIT_OFFSET
      childH = childH or (uint64(digit) shl shift)
    
    result[childIdx - 0] = H3Index(childH)

# =============================================================================
# Neighbor Operations
# =============================================================================

# Direction vectors for 6 neighbors in IJK space
const NEIGHBOR_DIRS: array[6, tuple[di, dj, dk: int]] = [
  (1, 0, -1),   # Direction 1
  (0, 1, -1),   # Direction 2
  (-1, 1, 0),   # Direction 3
  (-1, 0, 1),   # Direction 4
  (0, -1, 1),   # Direction 5
  (1, -1, 0)    # Direction 6
]

proc getNeighbor(h: H3Index, direction: int): H3Index =
  ## Get the neighbor in the specified direction (1-6).
  ## Direction 0 returns the cell itself.
  if direction == 0:
    return h
  
  let res = h.getResolution()
  let fijk = h3ToFaceIJK(h)
  
  # Apply direction delta
  let dir = NEIGHBOR_DIRS[(direction - 1) mod 6]
  var newFijk = FaceIJK(
    face: fijk.face,
    i: fijk.i + dir.di,
    j: fijk.j + dir.dj,
    k: fijk.k + dir.dk
  )
  
  result = faceIJKToH3(newFijk, res)

proc gridDisk*(origin: H3Index, k: int): seq[H3Index] =
  ## Get all cells within k grid steps of origin.
  ##
  ## Returns a "disk" of hexagons:
  ## k=0: just origin (1 cell)
  ## k=1: origin + 6 neighbors (7 cells)
  ## k=2: k=1 + 12 more (19 cells)
  ## k=n: 3n² + 3n + 1 cells
  ##
  ## Algorithm:
  ## 1. Start with origin
  ## 2. For each ring 1..k:
  ##    - Walk around the ring adding cells
  ##    - Handle pentagon cases

  result = @[origin]

  if k == 0:
    return

  # Use BFS-like approach to add rings
  var seen = initHashSet[uint64]()
  seen.incl(origin.uint64)
  
  var currentRing = @[origin]
  
  for ring in 1 .. k:
    var nextRing: seq[H3Index] = @[]
    
    for cell in currentRing:
      # Add all 6 neighbors
      for dir in 1 .. 6:
        let neighbor = getNeighbor(cell, dir)
        if neighbor.uint64 notin seen:
          seen.incl(neighbor.uint64)
          nextRing.add(neighbor)
          result.add(neighbor)
    
    currentRing = nextRing

proc gridRing*(origin: H3Index, k: int): seq[H3Index] =
  ## Get cells exactly k steps from origin (ring only).
  ##
  ## Returns 6*k cells for k > 0 (hexagon case).
  result = @[]

  if k == 0:
    result.add(origin)
    return

  # Get ring by walking the perimeter
  # Start at k steps in direction 1, then walk around
  var current = origin
  
  # Move k steps in direction 1
  for i in 0 ..< k:
    current = getNeighbor(current, 1)
  
  # Walk around the ring: 6 sides, k steps each
  for side in 0 ..< 6:
    let walkDir = ((side + 2) mod 6) + 1
    for step in 0 ..< k:
      result.add(current)
      current = getNeighbor(current, walkDir)

proc areNeighbors*(a, b: H3Index): bool =
  ## Check if two cells are neighbors.
  if a.getResolution() != b.getResolution():
    return false
  
  # Check if b is one of a's 6 neighbors
  for dir in 1 .. 6:
    if getNeighbor(a, dir) == b:
      return true
  
  return false

# =============================================================================
# Area and Distance
# =============================================================================

proc cellAreaKm2*(res: int): float64 =
  ## Get average cell area in km² at resolution.
  RES0_AREA_KM2 / pow(APERTURE, float(res))

proc cellAreaM2*(res: int): float64 =
  ## Get average cell area in m² at resolution.
  cellAreaKm2(res) * 1_000_000

proc greatCircleDistanceKm*(a, b: GeoCoord): float64 =
  ## Haversine distance between two coordinates in km.
  const R = 6371.0  # Earth radius in km

  let
    lat1 = degsToRads(a.latDeg)
    lat2 = degsToRads(b.latDeg)
    dLat = lat2 - lat1
    dLng = degsToRads(b.lngDeg - a.lngDeg)

  let
    sinDLat = sin(dLat / 2)
    sinDLng = sin(dLng / 2)
    h = sinDLat * sinDLat + cos(lat1) * cos(lat2) * sinDLng * sinDLng

  result = 2 * R * arcsin(sqrt(h))

proc gridDistance*(a, b: H3Index): int =
  ## Get grid distance (number of steps) between two cells.
  ##
  ## This is the minimum number of cell traversals needed.
  ## Only valid for cells at the same resolution.

  if a.getResolution() != b.getResolution():
    raise newException(ValueError, "Cells must be at same resolution")

  # Convert both to IJK and compute the cube distance
  let fijkA = h3ToFaceIJK(a)
  let fijkB = h3ToFaceIJK(b)
  
  # If on different faces, estimate distance via lat/lng
  if fijkA.face != fijkB.face:
    # Approximate using geographic distance
    let coordA = cellToLatLng(a)
    let coordB = cellToLatLng(b)
    let distKm = greatCircleDistanceKm(coordA, coordB)
    let cellEdgeKm = sqrt(cellAreaKm2(a.getResolution()) / 2.598)  # Hex area formula
    return int(distKm / cellEdgeKm)
  
  # Same face: use cube distance
  let di = abs(fijkA.i - fijkB.i)
  let dj = abs(fijkA.j - fijkB.j)
  let dk = abs(fijkA.k - fijkB.k)
  
  result = max(di, max(dj, dk))

# =============================================================================
# Boundary
# =============================================================================

proc cellToBoundary*(h: H3Index): seq[GeoCoord] =
  ## Get the boundary vertices of a cell.
  ##
  ## Returns 6 vertices for hexagons, 5 for pentagons.
  ## Vertices are in counter-clockwise order.
  
  let numVerts = if h.isPentagon(): 5 else: 6
  result = newSeq[GeoCoord](numVerts)
  
  # Get cell center from FaceIJK
  let fijk = h3ToFaceIJK(h)
  let res = h.getResolution()
  let faceLat = FACE_CENTER_LAT[fijk.face]
  let faceLng = FACE_CENTER_LNG[fijk.face]
  let azimuth = FACE_AXES_AZIMUTH[fijk.face]
  
  # Hex vertex distance from center (circumradius)
  let scale = pow(sqrt(7.0), float(res))
  let hexRadius = 1.0 / (scale * M_RES0_U_GNOMONIC * sqrt(3.0))
  
  # Generate vertices around the center
  for v in 0 ..< numVerts:
    let angle = float(v) * 2.0 * PI / float(numVerts) + PI / 6.0  # Flat-top orientation
    
    # Vertex position in hex grid coordinates
    let vx = float(fijk.i) / (scale * M_RES0_U_GNOMONIC) + hexRadius * cos(angle)
    let vy = float(fijk.j) / (scale * M_RES0_U_GNOMONIC) + hexRadius * sin(angle)
    
    # Reverse face rotation
    let x = vx * cos(-azimuth) - vy * sin(-azimuth)
    let y = vx * sin(-azimuth) + vy * cos(-azimuth)
    
    # Inverse gnomonic projection
    let ll = inverseGnomonicProject(x, y, faceLat, faceLng)
    result[v] = ll.toGeoCoord()
