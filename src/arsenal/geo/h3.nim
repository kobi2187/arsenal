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

import std/[math, bitops]

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

proc geoToFaceIJK(ll: LatLng, res: int): FaceIJK =
  ## Convert lat/lng to face-centered IJK coordinates.
  ##
  ## Algorithm:
  ## 1. Convert to 3D unit vector
  ## 2. Find containing icosahedron face
  ## 3. Gnomonic projection to face plane
  ## 4. Convert to IJK hex coordinates

  # Step 1: Spherical to Cartesian
  let
    cosLat = cos(ll.lat)
    x = cosLat * cos(ll.lng)
    y = cosLat * sin(ll.lng)
    z = sin(ll.lat)

  # Step 2: Find icosahedron face
  # The icosahedron has 20 faces, oriented using Dymaxion projection
  # to place vertices in oceans.
  #
  # TODO: Implement face lookup table
  # For now, simplified to single face
  result.face = 0

  # Step 3: Gnomonic projection
  # Project from sphere center through point to face tangent plane
  #
  # TODO: Implement actual gnomonic projection
  # Requires face center and orientation

  # Step 4: Convert to IJK
  # The IJK coordinate system uses three axes at 120° angles
  # i + j + k = 0 (constraint)
  #
  # TODO: Implement hex grid coordinate conversion

  result.i = 0
  result.j = 0
  result.k = 0

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

  # TODO: Look up base cell from face and IJK
  let baseCell = 0
  h = h or (uint64(baseCell) shl H3_BC_OFFSET)

  # TODO: Compute direction digits for each resolution level
  # For each level from 1 to res:
  #   Determine which of 7 children contains the point
  #   Encode as 3-bit digit

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

proc cellToLatLng*(h: H3Index): GeoCoord =
  ## Get the center coordinates of an H3 cell.
  ##
  ## Algorithm:
  ## 1. Extract base cell and direction digits
  ## 2. Convert to FaceIJK coordinates
  ## 3. Inverse gnomonic projection to sphere
  ## 4. Convert to lat/lng

  # TODO: Implement reverse conversion
  result = GeoCoord(latDeg: 0.0, lngDeg: 0.0)

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
  var result = h.uint64
  result = result and not H3_RES_MASK shl H3_RES_OFFSET
  result = result or (uint64(parentRes) shl H3_RES_OFFSET)

  # Zero out child digits
  for r in (parentRes + 1) .. MAX_RESOLUTION:
    let shift = (MAX_RESOLUTION - r) * H3_DIGIT_OFFSET
    result = result and not (H3_DIGIT_MASK shl shift)

  H3Index(result)

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
  let numChildren = if h.isPentagon(): 6 else: 7

  result = @[]

  # TODO: Generate all child combinations
  # For each level, iterate through 7 (or 6 for pentagon) digits

# =============================================================================
# Neighbor Operations
# =============================================================================

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

  # TODO: Implement k-ring traversal
  # For each ring, walk 6 * ringNum cells

proc gridRing*(origin: H3Index, k: int): seq[H3Index] =
  ## Get cells exactly k steps from origin (ring only).
  ##
  ## Returns 6*k cells for k > 0 (hexagon case).
  result = @[]

  if k == 0:
    result.add(origin)
    return

  # TODO: Implement ring traversal

proc areNeighbors*(a, b: H3Index): bool =
  ## Check if two cells are neighbors.
  # TODO: Implement neighbor check
  false

# =============================================================================
# Area and Distance
# =============================================================================

proc cellAreaKm2*(res: int): float64 =
  ## Get average cell area in km² at resolution.
  RES0_AREA_KM2 / pow(APERTURE, float(res))

proc cellAreaM2*(res: int): float64 =
  ## Get average cell area in m² at resolution.
  cellAreaKm2(res) * 1_000_000

proc gridDistance*(a, b: H3Index): int =
  ## Get grid distance (number of steps) between two cells.
  ##
  ## This is the minimum number of cell traversals needed.
  ## Only valid for cells at the same resolution.

  if a.getResolution() != b.getResolution():
    raise newException(ValueError, "Cells must be at same resolution")

  # TODO: Implement grid distance algorithm
  # Convert both to IJK, compute Manhattan distance
  0

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

# =============================================================================
# Boundary
# =============================================================================

proc cellToBoundary*(h: H3Index): seq[GeoCoord] =
  ## Get the boundary vertices of a cell.
  ##
  ## Returns 6 vertices for hexagons, 5 for pentagons.
  ## Vertices are in counter-clockwise order.

  # TODO: Implement boundary calculation
  # Requires inverse projection for each vertex
  result = @[]
