package starling.extensions.deferredShading.lights
{
	import flash.geom.Rectangle;
	import starling.display.DisplayObject;
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

			super(vertexData, indexData, null);
		}
		
		override public function render(painter:Painter):void
		{
			// ..
		}
		
		public override function getBounds(targetSpace:DisplayObject, resultRect:Rectangle=null):Rectangle
		{
			// TODO: refractor
			return new Rectangle();
		}
	}
}