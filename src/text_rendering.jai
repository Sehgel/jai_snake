#import "freetype-2.12.1";
#import "Hash_Table";

text_VAO, text_VBO : u32;
text_shader : GLuint;

init_text_rendering :: () {

	ft : FT_Library;

	if FT_Init_FreeType(*ft) {
		print("\nError: Couldn't init FreeType Library.");
		return;
	}

	face : FT_Face;

	if FT_New_Face(ft,"fonts/action_man.ttf",0,*face) {
		print("\nError: Failed to load font: action_man.ttf");
		return;
	}

	FT_Set_Pixel_Sizes(face,0,48);

	glPixelStorei(GL_UNPACK_ALIGNMENT, 1);
	//Load glyph
	for c : 32..126 {
		if FT_Load_Char(face,cast(u32)c,FT_LOAD_RENDER) {
			print("\nError: failed to load glyph: %",c);
			continue;
		}
		//Generate texture
		texture : u32;
		glGenTextures(1,*texture);
		glBindTexture(GL_TEXTURE_2D,texture);
		glTexImage2D(
			GL_TEXTURE_2D,
			0,
			GL_RED,
			face.glyph.bitmap.width,
			face.glyph.bitmap.rows,
			0,
			GL_RED,
			GL_UNSIGNED_BYTE,
			face.glyph.bitmap.buffer);

		// set texture options
	    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
	    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
	    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
	    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);


	    character := Character.{
	    	texture_id = texture,
	    	size = .{face.glyph.bitmap.width,face.glyph.bitmap.rows},
	    	bearing = .{face.glyph.bitmap_left,face.glyph.bitmap_top},
	    	advance = face.glyph.advance.x
	    };
	    table_add(*text_characters,c,character);
	}
	glBindTexture(GL_TEXTURE_2D, 0);

	FT_Done_Face(face);
	FT_Done_FreeType(ft);

	//Consider moving this to the main file
	glEnable(GL_BLEND);
	glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);

	glGenVertexArrays(1,*text_VAO);
	glGenBuffers(1,*text_VBO);
	glBindVertexArray(text_VAO);
	glBindBuffer(GL_ARRAY_BUFFER,text_VBO);
	glBufferData(GL_ARRAY_BUFFER,size_of(float) * 6 * 4,null,GL_DYNAMIC_DRAW);
	glEnableVertexAttribArray(0);
	glVertexAttribPointer(0,4,GL_FLOAT,GL_FALSE,size_of(float)*4,xx 0);
	glBindBuffer(GL_ARRAY_BUFFER,0);
	glBindVertexArray(0);

	//Shader
	text_shader = create_shader_program("shaders/text/text_vertex.glsl","shaders/text/text_fragment.glsl");


	/*
	for key, value : text_characters {
		print("\nKey: %, Value: %",key, value);
	}
	*/
	print("\n!Value: %",<<table_find_pointer(*text_characters,0));

}

render_text :: (text : string, x : float, y : float, scale : float, color : Vector3, projection : *Matrix4) {

	glUseProgram(text_shader);

	text_color_loc := glGetUniformLocation(text_shader,"text_color");
	projection_loc := glGetUniformLocation(text_shader,"projection");

	//backend_tweak_projection_matrix(*projection);
	glUniformMatrix4fv(projection_loc,1,GL_FALSE,xx projection);
	glUniform3f(text_color_loc,color.x,color.y,color.z);
	glActiveTexture(GL_TEXTURE0);
	glBindVertexArray(text_VAO);


	for char : text {

		glyph := <<table_find_pointer(*text_characters,char);

		x_pos : float = x + glyph.bearing.x * scale;
		y_pos : float = y - (xx glyph.size.y - glyph.bearing.y) * scale;
		//y_pos := y - ((<<table_find_pointer(*text_characters,#char "H")).bearing.y - glyph.bearing.y) * scale;

		w : float = glyph.size.x * scale;
		h : float = glyph.size.y * scale;

		// update VBO for each character

        vertices := float.[
        	x_pos,     y_pos + h,   0.0, 1.0,
        	x_pos + w, y_pos,       1.0, 0.0,
        	x_pos,     y_pos,       0.0, 0.0,

        	x_pos,     y_pos + h,   0.0, 1.0,
        	x_pos + w, y_pos + h,   1.0, 1.0,
        	x_pos + w, y_pos,       1.0, 0.0
        ];

		glBindTexture(GL_TEXTURE_2D, glyph.texture_id);
		glBindBuffer(GL_ARRAY_BUFFER,text_VBO);
		glBufferSubData(GL_ARRAY_BUFFER,0,size_of(float) * vertices.count,*vertices);
		//glBindBuffer(GL_ARRAY_BUFFER, 0);
		//Render
		glDrawArrays(GL_TRIANGLES,0,6);
		x += (glyph.advance >> 6) * scale;
	}
	glBindVertexArray(0);
	glBindTexture(GL_TEXTURE_2D,0);
}

text_characters : Table(int,Character);

Character :: struct {
	texture_id : u32;
	size : u32Vector2;
	bearing : s32Vector2;
	advance : s32;
}

u32Vector2 :: struct {
	x : u32;
	y : u32;
}

s32Vector2 :: struct {
	x : s32;
	y : s32;
}