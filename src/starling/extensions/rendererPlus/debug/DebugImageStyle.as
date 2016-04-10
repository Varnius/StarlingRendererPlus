// StarlingRendererPlus
// Copyright Simonas Pauliukevičius. All Rights Reserved.
//
// This program is free software. You can redistribute and/or modify it
// in accordance with the terms of the accompanying license agreement.

package starling.extensions.rendererPlus.debug
{
    import starling.rendering.MeshEffect;
    import starling.rendering.MeshStyle;
    import starling.rendering.RenderState;

    public class DebugImageStyle extends MeshStyle
    {
        override public function copyFrom(meshStyle:MeshStyle):void
        {
            var style:DebugImageStyle = meshStyle as DebugImageStyle;
            if(style)  _showChannel = style.showChannel;

            super.copyFrom(meshStyle);
        }

        override public function createEffect():MeshEffect
        {
            return new DebugImageEffect();
        }

        override public function updateEffect(effect:MeshEffect, state:RenderState):void
        {
            super.updateEffect(effect, state);
            (effect as DebugImageEffect)._showChannel = _showChannel;
        }

        override public function canBatchWith(meshStyle:MeshStyle):Boolean
        {
            if(meshStyle is DebugImageStyle)
            {
                super.canBatchWith(meshStyle);
            }
            else return false;
        }

        private var _showChannel:int = -1;
        // todo: cleanup
        // Valid values: -1, 0, 3
        public function get showChannel():int
        {
            return _showChannel;
        }

        public function set showChannel(value:int):void
        {
            _showChannel = value;
            setRequiresRedraw();
        }
    }
}
