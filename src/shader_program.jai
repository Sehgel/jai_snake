#import "File";

create_shader_program :: (vertex_file_path : string, fragment_file_path : string) -> GLuint {
	shader_program := glCreateProgram();

	//Vertex
	vertex_shader := glCreateShader(GL_VERTEX_SHADER);
	//File loading and cleaning
	vertex_shader_file := read_entire_file(vertex_file_path);
    defer free(vertex_shader_file);
	//Compilation
    glShaderSource(vertex_shader,1,*vertex_shader_file.data,null);
    glCompileShader(vertex_shader);
	//Error checking
    success : s32;
    glGetShaderiv(vertex_shader,GL_COMPILE_STATUS,*success);

    if !success {
        info_log : [256]u8;
        glGetShaderInfoLog(vertex_shader,info_log.count,null,info_log.data);
        print("\nERROR: Vertex Shader compilation failed: %",cast(string)info_log);
        return cast(GLuint)0;
    }


	//Fragment
	fragment_shader := glCreateShader(GL_FRAGMENT_SHADER);
	//File loading and cleaning
    fragment_shader_file := read_entire_file(fragment_file_path);
    defer free(fragment_shader_file);
    //Compilation
    glShaderSource(fragment_shader,1,*fragment_shader_file.data,null);
    glCompileShader(fragment_shader);
    //Error checking

    glGetShaderiv(fragment_shader,GL_COMPILE_STATUS,*success);

    if !success {
        info_log : [256]u8;
        glGetShaderInfoLog(fragment_shader,info_log.count,null,info_log.data);
        print("\nERROR: Fragment Shader compilation failed: %",cast(string)info_log);
        return cast(GLuint)0;
    }

	//Linking
    glAttachShader(shader_program, vertex_shader);
    glAttachShader(shader_program, fragment_shader);
    glLinkProgram(shader_program);
	//Error checking
    glGetProgramiv(shader_program,GL_LINK_STATUS,*success);
    if !success {
        info_log : [256]u8;
        glGetProgramInfoLog(shader_program,info_log.count,null,info_log.data);
        print("\n[155]ERROR: Linking program failed: %",cast(string)info_log);
        return cast(GLuint)0;
    }
    glDeleteShader(vertex_shader);
    glDeleteShader(fragment_shader);

    print("Successfully created shader: %\n",shader_program);
    return shader_program;
}