// StarlingRendererPlus
// Copyright Simonas Pauliukevičius. All Rights Reserved.
//
// This program is free software. You can redistribute and/or modify it
// in accordance with the terms of the accompanying license agreement.

package starling.extensions.rendererPlus
{
    /**
     * Defines available render pass types.
     */
    public class RenderPass
    {
        public static const NORMAL:String = 'Normal';
        public static const MRT:String = 'MRT';
        public static const LIGHTS:String = 'Lights';
        public static const OCCLUDERS:String = 'Occluders';
        public static const SHADOWMAP:String = 'Shadowmap';
    }
}