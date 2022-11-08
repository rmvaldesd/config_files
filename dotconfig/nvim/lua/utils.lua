local M = {}

function M.get_current_file_name() 
    filename = vim.api.nvim_buf_get_name(0)
    if not filename then
        print("No Name.") 
    end
    print(filename)
end

return M
