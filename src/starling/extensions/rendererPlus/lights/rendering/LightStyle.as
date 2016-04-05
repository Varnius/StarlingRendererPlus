// StarlingRendererPlus
// Copyright Simonas Pauliukevičius. All Rights Reserved.
//
// This program is free software. You can redistribute and/or modify it
// in accordance with the terms of the accompanying license agreement.

/**
 * Created by Derpy on 2016.03.25.
 */
package starling.extensions.rendererPlus.lights.rendering
{
    import starling.extensions.rendererPlus.renderer_internal;
    import starling.rendering.MeshStyle;

    use namespace renderer_internal;

    public class LightStyle extends MeshStyle
    {
        public function LightStyle()
        {
            color = 0x888888;
            strength = 1.0;
        }

        override public function copyFrom(meshStyle:MeshStyle):void
        {
            var s:LightStyle = meshStyle as LightStyle

            _color = s.color;
            _colorR = s._colorR;
            _colorG = s._colorG;
            _colorB = s._colorB;
            _strength = s._strength;

            super.copyFrom(meshStyle);
        }

        // Props

        protected var _color:uint;
        renderer_internal var _colorR:Number;
        renderer_internal var _colorG:Number;
        renderer_internal var _colorB:Number;

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

        protected var _strength:Number;

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
