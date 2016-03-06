package starling.extensions.deferredShading.lights
{
    import starling.display.Mesh;
    import starling.extensions.deferredShading.RenderPass;
    import starling.extensions.deferredShading.display.DeferredShadingContainer;
    import starling.extensions.deferredShading.renderer_internal;
    import starling.rendering.IndexData;
    import starling.rendering.MeshStyle;
    import starling.rendering.Painter;
    import starling.rendering.VertexData;

    use namespace renderer_internal;

    /**
     * Base for all types of lights.
     * Use one of the subclasses instead.
     */
    public class Light extends Mesh
    {
        public function Light(vertexData:VertexData, indexData:IndexData, style:MeshStyle)
        {
            super(vertexData, indexData, style);
        }

        override public function render(painter:Painter):void
        {
            if(DeferredShadingContainer.renderPass == RenderPass.LIGHTS) super.render(painter);
        }

        /*-----------------------------
         Properties
         -----------------------------*/

        protected var _color:uint = 0xffffff;
        renderer_internal var _colorR:Number = 1.0;
        renderer_internal var _colorG:Number = 1.0;
        renderer_internal var _colorB:Number = 1.0;

        override public function get color():uint
        {
            return _color;
        }

        override public function set color(value:uint):void
        {
            _colorR = ((value >> 16) & 0xff) / 255.0;
            _colorG = ((value >> 8) & 0xff) / 255.0;
            _colorB = ( value & 0xff) / 255.0;
            _color = value;
        }

        protected var _strength:Number = 1.0;

        public function get strength():Number
        {
            return _strength;
        }

        public function set strength(value:Number):void
        {
            _strength = value;
        }
    }
}