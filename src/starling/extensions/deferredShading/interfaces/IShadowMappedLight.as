package starling.extensions.deferredShading.interfaces
{
	import flash.display3D.IndexBuffer3D;
	import flash.display3D.VertexBuffer3D;
	
	import starling.core.RenderSupport;
	import starling.textures.Texture;

	public interface IShadowMappedLight
	{
		/**
		 * The light will cast shadows if set to true.
		 */
		function get castsShadows():Boolean;
		function set castsShadows(value:Boolean):void;
		
		/**
		 * Shadow map render target.
		 */
		function get shadowMap():Texture;
		
		/**
		 * Renders shadow map for the light.
		 */
		function renderShadowMap(
			support:RenderSupport,
			occluders:Texture,
			vertexBuffer:VertexBuffer3D,
			indexBuffer:IndexBuffer3D
		):void;
	}
}