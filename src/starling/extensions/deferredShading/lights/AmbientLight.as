package starling.extensions.deferredShading.lights
{
	import flash.geom.Rectangle;
	
	import starling.core.RenderSupport;
	import starling.display.DisplayObject;

	/**
	 * Represents an even amount of light, added to each pixel on the screen.
	 * Use color property to set exact amount of light to add, strength property has no effect with AmbientLight. 
	 */
	public class AmbientLight extends Light
	{
		private var bounds:Rectangle = new Rectangle();
		
		public function AmbientLight(color:uint)
		{
			super(color);
		}
		
		override public function render(support:RenderSupport, parentAlpha:Number):void
		{
			// ..
		}
		
		public override function getBounds(targetSpace:DisplayObject, resultRect:Rectangle=null):Rectangle
		{
			return bounds;
		}
	}
}