package starling.extensions.deferredShading.interfaces
{
	public interface IAreaLight
	{
		/**
		 * Light radius in pixels.
		 */
		function get radius():Number;
		function set radius(value:Number):void;
		
		/**
		 * Attenuation coefficient. Lesser values mean more spread light.
		 * If value is negative or equal to zero, it will be set to Number.MIN_VALUE.
		 */
		function get attenuation():Number;
		function set attenuation(value:Number):void;
		
		function get castsShadows():Boolean;
		function set castsShadows(value:Boolean):void;
	}
}