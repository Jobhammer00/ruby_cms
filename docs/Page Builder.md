# Page Builder

The Page Builder is a drag-and-drop interface for building pages using components. It supports both built-in primitives and RubyUI components from your host application.

## Features

- **Drag-and-drop interface** - Build pages visually by dragging components
- **Component palette** - Browse and search available components
- **Props editor** - Edit component properties with a visual form
- **Nested components** - Build complex layouts by nesting components
- **Live preview** - See your changes in real-time
- **RubyUI integration** - Automatically use RubyUI components from your app

## File Structure

The page builder functionality is organized as follows:

### Controllers

- `app/controllers/ruby_cms/admin/page_builder_controller.rb` - Main page builder controller

### Helpers

- `app/helpers/ruby_cms/page_builder_helper.rb` - Page builder view helpers

### Views

- `app/views/ruby_cms/admin/page_builder/` - All page builder views
  - `index.html.erb` - Page builder index/selection
  - `show.html.erb` - Page builder canvas
  - `_node.html.erb` - Node partial
  - `_node_template.html.erb` - Node template for JavaScript

### JavaScript

- `app/javascript/controllers/ruby_cms/page_builder_controller.js` - Stimulus controller for page builder

### Library Code

- `lib/ruby_cms/page_builder.rb` - Main module
- `lib/ruby_cms/page_builder/component_registry.rb` - Component registry extensions
- `lib/ruby_cms/page_builder/ruby_ui_discovery.rb` - RubyUI component discovery

## Built-in Components

The page builder includes several built-in primitive components:

### Layout Primitives

- **Div** - Simple container
- **Container** - Container with max-width and padding
- **Section** - Section with vertical spacing
- **Stack** - Vertical stack with gap
- **Grid** - Responsive grid layout

### Content Primitives

- **Heading** - Heading text with configurable level and size
- **Text** - Paragraph text

## RubyUI Integration

The page builder automatically discovers and registers specific RubyUI components from your host application. This happens automatically when `rails_ui` is installed - no configuration needed!

### Automatic Component Discovery

When you install `rails_ui` in your host app, the following RubyUI components are **automatically** discovered and available in the page builder:

- **Button** (`ruby_ui.button`) - Interactive button component
- **Text** (`ruby_ui.text`) - Typography text component
- **Heading** (`ruby_ui.heading`) - Typography heading component
- **DropdownMenu** (`ruby_ui.dropdown_menu`) - Dropdown menu component
- **Sidebar** (`ruby_ui.sidebar`) - Sidebar navigation component (if available)

### How It Works

The page builder automatically discovers these components when `rails_ui` is installed. No configuration needed!

1. **Install `rails_ui`** in your host app's Gemfile:

   ```ruby
   gem "rails_ui", ">= 1.0"
   ```

2. **Create RubyUI components** in `app/components/ruby_ui/`:
   - `app/components/ruby_ui/button/button.rb` → `RubyUI::Button`
   - `app/components/ruby_ui/typography/text.rb` → `RubyUI::Text`
   - `app/components/ruby_ui/typography/heading.rb` → `RubyUI::Heading`
   - `app/components/ruby_ui/dropdown_menu/dropdown_menu.rb` → `RubyUI::DropdownMenu`
   - `app/components/ruby_ui/sidebar/sidebar.rb` → `RubyUI::Sidebar` (if you have this component)

3. **Components appear automatically** in the page builder palette - no registration needed!

The page builder uses Rails autoloading to discover components. As long as your components:

- Are in `app/components/ruby_ui/`
- Inherit from `RubyUI::Base`
- Follow the naming convention (e.g., `Button` → `RubyUI::Button`)

They will be automatically available in the page builder.

### Component Schemas

Components can define schemas for their props. The page builder will use these schemas to:

- Generate property forms
- Validate props
- Provide default values

Example:

```ruby
module RubyUI
  class Button < Base
    def self.schema
      {
        type: "object",
        properties: {
          label: { type: "string", default: "Click me" },
          variant: { type: "string", enum: %w[primary secondary], default: "primary" },
          size: { type: "string", enum: %w[sm md lg], default: "md" }
        },
        required: ["label"]
      }
    end
  end
end
```

### Adding More RubyUI Components

Currently, only Button, Text, Heading, DropdownMenu, and Sidebar are automatically discovered. To add more RubyUI components, you can register them manually in your initializer:

```ruby
# config/initializers/ruby_cms.rb
RubyCms.configure do |c|
  c.component_registry.register(
    key: "ruby_ui.card",
    name: "Card",
    category: "Layout",
    description: "RubyUI Card component",
    schema: {},
    render: ->(view, props, &block) {
      view.render(RubyUI::Card.new(**props.symbolize_keys), &block)
    }
  )
end
```

## Usage

### Creating a Page

1. Go to **Admin → Pages** and create a new page
2. Set the render mode to "builder"
3. Click "Open Page Builder" or go to **Admin → Page Builder**

### Building with Components

1. **Drag components** from the left palette to the canvas
2. **Click a component** to select it and edit its properties
3. **Drag components onto other components** to nest them
4. **Reorder components** by dragging them within their container
5. **Delete components** using the delete button

### Editing Component Properties

1. Click on any component in the canvas
2. The props editor will appear on the right
3. Edit the properties using the generated form
4. Click "Save Properties" to update the component

### Saving Your Work

Click "Save Changes" in the toolbar to persist your page structure. The page will be compiled and available at `/p/:key`.

## Component Categories

Components are organized by category in the palette:

- **Layout** - Structural components (Div, Container, Section, etc.)
- **Content** - Content components (Heading, Text, Typography, etc.)
- **Forms** - Form components (Button, Input, etc.)
- **Navigation** - Navigation components (Sidebar, etc.)
- **Interactive** - Interactive components (DropdownMenu, etc.)

## Advanced Features

### Nested Components

You can nest components by dragging a component onto another component. This creates a parent-child relationship in the component tree.

### Component Reordering

Drag components within their container to reorder them. The position is automatically saved.

### Regions

Pages can have multiple regions (e.g., "header", "main", "footer"). Each region can contain its own component tree.

### Component Dependencies

Some components may depend on others. The page builder validates dependencies when you try to use a component.

## Troubleshooting

### Components Not Appearing

- Ensure `rails_ui` is installed in your Gemfile
- Check that components are in `app/components/ruby_ui/`
- Verify components inherit from `RubyUI::Base`
- Check the Rails server logs for autoloading errors

### Props Editor Not Working

- Ensure the component has a valid schema
- Check browser console for JavaScript errors
- Verify the component class can be loaded

### Drag and Drop Not Working

- Check that Stimulus controllers are properly registered
- Verify JavaScript assets are compiled
- Check browser console for errors
