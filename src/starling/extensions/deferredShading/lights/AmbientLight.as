package starling.extensions.deferredShading.lights
{
    import flash.geom.Rectangle;

    import starling.display.DisplayObject;
    import starling.extensions.deferredShading.lights.rendering.LightStyle;
    import starling.rendering.IndexData;
    import starling.rendering.MeshStyle;
    import starling.rendering.Painter;
    import starling.rendering.VertexData;

    /**
     * Represents an even amount of light, added to each pixel on the screen.
     * Use color property to set exact amount of light to add, strength property has no effect with AmbientLight.
     */
    public class AmbientLight extends Light
    {
        public function AmbientLight()
        {
            var vertexData:VertexData = new VertexData(MeshStyle.VERTEX_FORMAT, 4);
            var indexData:IndexData = new IndexData(6);
            var style:LightStyle = new LightStyle();

            super(vertexData, indexData, style);
        }

        override public function render(painter:Painter):void
        {
            return;
        }

        public override function getBounds(targetSpace:DisplayObject, resultRect:Rectangle = null):Rectangle
        {
           return null;
        }
    }
}