/**
* Surface object that can be distorted using a bunch of control points to fit an irregular
* 3D surface. Its corner coordinates define a Region Of Interest that will be drawn as a texture
* from a Canvas
* @author    Marc Vilella
* @version   1.1b
*/

import java.util.Observable;

public class WarpSurface extends Observable {
    
    private final String CONFIG_FILE_PATH;
    
    private LatLon[][] ROIPoints;
    private PVector[][] controlPoints;
    private int cols, rows;
    
    private boolean calibrate;
    private PVector controlPoint;
    
    private WarpCanvas prevCanvas = null;    
    private PVector[][] drawROI;
    
    
    /**
    * Construct a warp surface containing a grid of control points. By default the surface
    * is placed at the center of sketch
    * @param parent    the sketch PApplet
    * @param width     the surface width
    * @param height    the surface height
    * @param cols      the number of horizontal control points
    * @param rows      the number of vertical control points
    */
    public WarpSurface(PApplet parent, float width, float height, int cols, int rows, LatLon[] roi) {
       
        CONFIG_FILE_PATH = "warpsurface_default.xml";
        
        this.cols = cols;
        this.rows = rows;
        
        float initX = parent.width / 2 - width / 2;
        float initY = parent.height / 2 - height / 2;
        float dX = width / (cols - 1);
        float dY = height / (rows - 1);
        
        controlPoints = new PVector[cols][rows];
        for(int c = 0; c < cols; c++) {
            for(int r = 0; r < rows; r++) {
                controlPoints[c][r] = new PVector(initX + c * dX, initY + r * dY);
            }
        }
        
        ROIPoints = getPointsROI(roi);
        
        parent.registerMethod("mouseEvent", this);
        parent.registerMethod("keyEvent", this);
    }
    
    
    /** 
    * Construct a warp surface containing a grid of control points. All parameters are loaded from
    * the previously created XML file called surface.xml
    * @param parent    the sketch PApplet
    */
    public WarpSurface(PApplet parent, String configFilePath) {
        parent.registerMethod("mouseEvent", this);
        parent.registerMethod("keyEvent", this);
        CONFIG_FILE_PATH = configFilePath;
        this.loadConfig(configFilePath);
    }


    /**
    * Return coordinates of corners in Region Of Interest
    * @return coordinates of vertices
    */
    public LatLon[] getROI() {
        return new LatLon[] {
            ROIPoints[0][0],
            ROIPoints[ROIPoints.length-1][0],
            ROIPoints[ROIPoints.length-1][ROIPoints[0].length-1],
            ROIPoints[0][ROIPoints[0].length-1]
        };
    }
    
    
    /**
    * Find all points inside a Region of Interest that match with rows and columns
    * @param roi    List of vertices of the region of interest (clockwise)
    * @return all points of the ROI
    */
    private LatLon[][] getPointsROI(LatLon[] roi) {
        LatLon[][] points = new LatLon[cols][rows];
        for(int c = 0; c < cols; c++) {
            LatLon upPoint = roi[0].lerp(roi[1], c/float(cols-1));
            LatLon dwPoint = roi[3].lerp(roi[2], c/float(cols-1));
            for(int r = 0; r < rows; r++) {
                points[c][r] = upPoint.lerp(dwPoint, r/float(rows-1));
            }
        }
        return points;
    }
    
    
    /**
    * Load the surface configuration parameters from an XML file
    * @param configFilePath    the path of the configuration XML file
    */
    public void loadConfig(String configFilePath) {
        File configFile = new File(sketchPath(configFilePath));
        if(configFile.exists()) {
            XML surface = loadXML(sketchPath(configFilePath));
            XML size = surface.getChild("size");
                rows = size.getInt("rows");
                cols = size.getInt("cols");
            XML roi[] = surface.getChild("roi").getChildren("location");
            LatLon[] ROI = new LatLon[roi.length];
            for(int i = 0; i < roi.length; i++) ROI[i] = new LatLon(roi[i].getFloat("lat"), roi[i].getFloat("lon"));
            ROIPoints = getPointsROI(ROI);
            prevCanvas = null;
            XML[] points = surface.getChild("points").getChildren("point");
            controlPoints = new PVector[cols][rows];
            for(int i = 0; i < points.length; i++) {
                int c = i % cols;
                int r = i / cols;
                controlPoints[c][r] = new PVector(points[i].getFloat("x"), points[i].getFloat("y"));
            }
            println("WarpSurface calibration loaded");
        } else throw new IllegalArgumentException("WarpSurface calibration file does not exist");
    }
    
    
    /**
    * Save the surface configuration parameters into an XML file
    * @param configFilePath    the path of the configuration XML file
    */
    public void saveConfig(String configFilePath) {
        if(calibrate) {
            XML surface = new XML("surface");
            XML roi = surface.addChild("roi");
            for(LatLon r : getROI()) {
                XML location = roi.addChild("location");
                location.setFloat("lat", r.getLat());
                location.setFloat("lon", r.getLon());
            }
            XML size = surface.addChild("size");
                size.setInt("cols", cols);
                size.setInt("rows", rows);
            XML xmlPoints = surface.addChild("points");
            for(int y = 0; y < rows; y++) {
                for(int x = 0; x < cols; x++) {
                    XML point = xmlPoints.addChild("point");
                    point.setFloat("x", controlPoints[x][y].x);
                    point.setFloat("y", controlPoints[x][y].y);
                }
            }
            saveXML(surface, configFilePath);
            println("WarpSurface calibration saved");
        }
    }
    
    
    /**
    * Draw the scene in surface, warping its canvas as a texture. While in calibration mode
    * the control points can be moved with a mouse drag
    * @param canvas    the canvas to draw 
    */
    public void draw(WarpCanvas canvas) {
        
        if(!canvas.equals(prevCanvas)) { // Update drawROI points if canvas changed
            drawROI = canvas.toScreen(ROIPoints);
            prevCanvas = canvas;
        }

        if(calibrate) {
            stroke(#FF0000);
            strokeWeight(0.5);
        } else noStroke();
        
        for(int r = 1; r < rows; r++) {
            beginShape(TRIANGLE_STRIP);
            texture(canvas);
            for(int c = 0; c < cols; c++) {
                vertex(controlPoints[c][r].x, controlPoints[c][r].y, drawROI[c][r].x, drawROI[c][r].y);
                vertex(controlPoints[c][r-1].x, controlPoints[c][r-1].y, drawROI[c][r-1].x, drawROI[c][r-1].y);
            }
            endShape();
        }
        
    }
    
    
    /**
    * Toggle callibration mode of surface, allowing to drag and move control points
    */
    public void toggleCalibration() {
        calibrate = !calibrate;
    }
    
    
    /**
    * Return whether the surface is in calibration mode
    * @return    true if surface is in calibration mode, false otherwise
    */
    public boolean isCalibrating() {
        return calibrate;
    }
    
    
    /**
    * Mouse event handler to perform control point dragging and point unmapping
    * @param e    the mouse event
    */
    public void mouseEvent(MouseEvent e) {
        switch(e.getAction()) {
            case MouseEvent.PRESS:
                if(calibrate) controlPoint = getControlPoint(e.getX(), e.getY());
                else {
                    PVector location = unmapPoint(e.getX(), e.getY());
                    if(location != null) {
                        setChanged();
                        notifyObservers(location);
                    }
                }
                break;
            case MouseEvent.DRAG:
                if(calibrate && controlPoint != null) {
                    controlPoint.x = e.getX();
                    controlPoint.y = e.getY();
                }
                break;
            case MouseEvent.RELEASE:
                controlPoint = null;
                break;
        }
    }
    
    
    /**
    * Key event handler to perform calibration movement of the surface
    * @param e    the key event
    */
    public void keyEvent(KeyEvent e) {
        if(calibrate) {
            switch(e.getAction()) {
                case KeyEvent.PRESS:
                    switch(e.getKey()) {
                        case 's':
                            if(calibrate) saveConfig(CONFIG_FILE_PATH);
                            break;
                        case 'l':
                            if(calibrate) loadConfig(CONFIG_FILE_PATH);
                        case CODED:
                            switch(e.getKeyCode()) {
                                case UP:
                                    this.move(0,-5);
                                    break;
                                case DOWN:
                                    this.move(0,5);
                                    break;
                                case LEFT:
                                    this.move(-5,0);
                                    break;
                                case RIGHT:
                                    this.move(5,0);
                                    break;
                            }
                            break;
                    }
            }
        }
    }
    
    
    /**
    * Move the whole surface across the screen
    * @param dX    Pixels to move in x direction
    * @param dY    Pixels to move in y direction
    */
    protected void move(int dX, int dY) {
        for(int c = 0; c < cols; c++) {
            for(int r = 0; r < rows; r++) {
                controlPoints[c][r].x += dX;
                controlPoints[c][r].y += dY;
            }
        }
    }
    
    
    /**
    * Get the control point close enough (if any) to a position
    * @param x    Horizontal position
    * @param y    Vertical position
    * @return the selected control point
    */
    private PVector getControlPoint(int x, int y) {
        PVector mousePos = new PVector(x, y);
        for(int c = 0; c < cols; c++) {    
            for(int r = 0; r < rows; r++) {
                if(mousePos.dist(controlPoints[c][r]) < 10) return controlPoints[c][r];
            }
        }
        return null;
    }
    
    
    /**
    * Unmap point position in the surface to get the corresponding location in latitude and longitude coordinates
    * @param x    Horizontal position
    * @param y    Vertical position
    * @return the latitude and longitude of the point
    */
    public LatLon unmapPoint(int x, int y) {
      return unmapPoint(new PVector(x, y));
    }
    
    
    /**
    * Unmap point position in the surface to get the corresponding location in latitude and longitude coordinates
    * @param point    Position in the surface
    * @return the latitude and longitude of the point
    */
    public LatLon unmapPoint(PVector point) {
        for(int r = 1; r < rows; r++) {
            for(int c = 1; c < cols; c++) {
                LatLon tp = triangleLocation(point, c, r, c, r-1);    // Upper triangle
                if(tp != null) return tp;
                tp = triangleLocation(point, c, r, c-1, r);    // Lower triangle
                if(tp != null) return tp;
            }
        }
        return null;
    }
    
    
     /**
    * Map location in the surface to get the corresponding position in x and y screen coordinates
    * @param lat    Latitude of the location
    * @param lon    Longitude of the location
    * @return the x and y position in surface of the location
    */
    public PVector mapPoint(float lat, float lon) {
      return mapPoint(new LatLon(lat, lon));
    }
    
    
    /**
    * Map location in the surface to get the corresponding position in x and y screen coordinates
    * @param location    Latitude and longitude of the location
    * @return the x and y position in surface of the location
    */
    public PVector mapPoint(LatLon location) {
        for(int r = 1; r < rows; r++) {
            for(int c = 1; c < cols; c++) {
                PVector tp = trianglePosition(location, c, r, c, r-1);    // Upper triangle
                if(tp != null) return tp;
                tp = trianglePosition(location, c, r, c-1, r);    // Lower triangle
                if(tp != null) return tp;
            }
        }
        return null;
    }
    
    
    /**
    * Get the location in the WarpSurface's border closer to the target location
    * @param location    Latitude and longitude of the location
    * @return the closest location coordinates in the WarpSurface's border
    */
    public LatLon closerBorderLocation(LatLon location) {
      LatLon[] ROI = getROI();
      LatLon closerBorderLocation = null;
      float minDistance = Float.MAX_VALUE;
      for(int i = 1; i < ROI.length; i++) {
        LatLon borderLocation = (LatLon) Geometry.closerLinePoint(location, ROI[i-1], ROI[i]);
        float distance = location.dist(borderLocation);
        if(location.dist(borderLocation) < minDistance) {
          closerBorderLocation = borderLocation;
          minDistance = distance;
        }
      }
      return closerBorderLocation;
    }
    
    
    /**
    * Get the location in the intersection between the WarpSurface's border and the
    * line defined by two locations
    * @param inLocation  Location coordinates inside the WarpSurface
    * @param outLocation Location coordinates outside the WarpSurface
    * @return the intersection location coordinates if line intersects the border, null otherwise
    */
    public LatLon borderIntersectionLocation(LatLon inLocation, LatLon outLocation) {
      LatLon[] ROI = getROI();
      for(int i = 1; i < ROI.length; i++) {
        LatLon intersection = (LatLon) Geometry.linesIntersection(inLocation, outLocation, ROI[i-1], ROI[i]);
        if(intersection != null) return intersection;
      }
      return null;
    }
    
    
    /**
    * Triangulate a surface's triangle to get the corresponding LatLon location
    * @param point    Screen point in the surface's triangle (if in triangle)
    * @param c        Column index of the triangle's vertex
    * @param r        Row index of the triangle's vertex
    * @param i        Column index of the quad vertex to select upper or lower triangle
    * @param j        Row index of the quad vertex to select upper or lower triangle 
    * @return the LatLon location of the point in the surface's triangle, null if point is not in the triangle
    */
    protected LatLon triangleLocation(PVector point, int c, int r, int i, int j) {
        if(Geometry.inTriangle(point, controlPoints[c][r], controlPoints[c-1][r-1], controlPoints[i][j])) {
            PVector projPoint = Geometry.linesIntersection(controlPoints[c-1][r-1], point, controlPoints[i][j], controlPoints[c][r]);
            float r1 = PVector.sub(projPoint, controlPoints[i][j]).mag() / PVector.sub(controlPoints[i][j], controlPoints[c][r]).mag();
            float r2 = PVector.sub(point, controlPoints[c-1][r-1]).mag() / PVector.sub(projPoint, controlPoints[c-1][r-1]).mag();
            LatLon decProjPoint = ROIPoints[i][j].lerp(ROIPoints[c][r], r1);
            return ROIPoints[c-1][r-1].lerp(decProjPoint, r2);
        } else return null;
    }
    
    
    /**
    * Triangulate a surface's triangle to get the corresponding x,y position
    * @param location Location coordinates in the triangle (if in triangle)
    * @param c        Column index of the triangle's vertex
    * @param r        Row index of the triangle's vertex
    * @param i        Column index of the quad vertex to select upper or lower triangle
    * @param j        Row index of the quad vertex to select upper or lower triangle 
    * @return the LatLon location of the point in the surface's triangle, null if point is not in the triangle
    */
    protected PVector trianglePosition(LatLon location, int c, int r, int i, int j) {
        if(Geometry.inTriangle(location, ROIPoints[c][r], ROIPoints[c-1][r-1], ROIPoints[i][j])) {
            PVector projPoint = Geometry.linesIntersection(ROIPoints[c-1][r-1], location, ROIPoints[i][j], ROIPoints[c][r]);
            float r1 = PVector.sub(projPoint, ROIPoints[i][j]).mag() / PVector.sub(ROIPoints[i][j], ROIPoints[c][r]).mag();
            float r2 = PVector.sub(location, ROIPoints[c-1][r-1]).mag() / PVector.sub(projPoint, ROIPoints[c-1][r-1]).mag();
            PVector decProjPoint = PVector.lerp(controlPoints[i][j], controlPoints[c][r], r1);
            return PVector.lerp(controlPoints[c-1][r-1], decProjPoint, r2);
        } else return null;
    }
    
}
