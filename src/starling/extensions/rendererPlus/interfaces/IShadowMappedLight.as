// StarlingRendererPlus
// Copyright Simonas Pauliukevičius. All Rights Reserved.
//
// This program is free software. You can redistribute and/or modify it
// in accordance with the terms of the accompanying license agreement.

package starling.extensions.rendererPlus.interfaces
{
	import flash.display3D.IndexBuffer3D;
	import flash.display3D.VertexBuffer3D;

import starling.rendering.Painter;
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
			painter:Painter,
			occluders:Texture,
			vertexBuffer:VertexBuffer3D,
			indexBuffer:IndexBuffer3D
		):void;
	}
}