// source https://godotshaders.com/shader/pixel-outline-for-tilemaps/
shader_type canvas_item;
render_mode world_vertex_coords;

const int SHADER_MAX_INTS = 2048;

uniform uint sides[SHADER_MAX_INTS];
uniform vec4 outline_color:source_color;
uniform float tile_size = 16;
uniform float tilemap_width = 256;

varying vec2 world_coord;

// to match the enum in maskable_tilemap.gd
const uint NONE = uint(0);
const uint TOP = uint(1);
const uint RIGHT = uint(2);
const uint BOT = uint(4);
const uint LEFT = uint(8);

void vertex() {
    world_coord = VERTEX;
}

void fragment() {
	vec2 block_coord = floor(world_coord / tile_size);
	vec2 relative_world_coord = floor(world_coord - (tile_size * block_coord));
	vec2 relative_block_coord = floor(block_coord);
	uint side_index = uint(relative_block_coord.x + (relative_block_coord.y * tilemap_width));
	uint side_data = sides[side_index];
	
	// top
	if((side_data & TOP) != NONE)
	{
		if (uint(0) == uint(relative_world_coord.y))
		{
			COLOR = outline_color;
		}
	}

	// right
	if( (side_data & RIGHT) != NONE)
	{
		if(uint(tile_size - 1.0) == uint(relative_world_coord.x))
		{
			COLOR = outline_color;
		}
	}

	// bot
	if( (side_data & BOT) != NONE)
	{
		if(uint(tile_size - 1.0) == uint(relative_world_coord.y))
		{
			COLOR = outline_color;
		}
	}

	// left
	if( (side_data & LEFT) != NONE )
	{
		if(uint(0) == uint(relative_world_coord.x))
		{ 
			COLOR = outline_color;
		}
	}
}
