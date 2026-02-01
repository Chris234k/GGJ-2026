// source https://godotshaders.com/shader/pixel-outline-for-tilemaps/
shader_type canvas_item;
render_mode world_vertex_coords;

uniform uint sides[256];
uniform vec4 outline_color:source_color;
uniform float tile_size = 16;
uniform float chunk_size = 1;

varying vec2 world_coord;

void vertex() {
    world_coord = VERTEX;
}

void fragment() {
	vec2 block_coord = floor(world_coord / tile_size);
	vec2 relative_world_coord = floor(world_coord - (tile_size * block_coord));
	vec2 chunk_coord = floor(block_coord / chunk_size);
	vec2 relative_block_coord = floor(block_coord - (chunk_size * chunk_coord));
	uint side_index = uint(relative_block_coord.x + relative_block_coord.y * tile_size);
	uint side_data = sides[side_index];
	
	// top
	if((side_data & uint(1)) != uint(0))
	{
		if (uint(0) == uint(relative_world_coord.y))
		{
			COLOR = outline_color;
		}
	}

	// right
	if( (side_data & uint(2)) != uint(0))
	{
		if(uint(tile_size - 1.0) == uint(relative_world_coord.x))
		{
			COLOR = outline_color;
		}
	}

	// bot
	if( (side_data & uint(4)) != uint(0))
	{
		if(uint(tile_size - 1.0) == uint(relative_world_coord.y))
		{
			COLOR = outline_color;
		}
	}

	// left
	if( (side_data & uint(8)) != uint(0) )
	{
		if(uint(0) == uint(relative_world_coord.x))
		{ 
			COLOR = outline_color;
		}
	}
}
