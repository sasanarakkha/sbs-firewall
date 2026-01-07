import htmlmin from "html-minifier-terser";
import * as sass from "sass";

export default function (eleventyConfig) {
  eleventyConfig.setInputDirectory("html");
  eleventyConfig.setOutputDirectory("tree/www/tickets");
  eleventyConfig.setTemplateFormats("html");
  eleventyConfig.addFilter("sass", (code) => {
    return sass.compileString(code, {
      loadPaths: ["node_modules/@picocss/pico/scss"],
      silenceDeprecations: ["if-function"],
    }).css;
  });
  eleventyConfig.addTransform("htmlmin", function (content, outputPath) {
    if (outputPath && outputPath.endsWith(".html")) {
      return htmlmin.minify(content, {
        collapseWhitespace: true,
        minifyCSS: false, // true,
        minifyJS: false, // true,
        preserveLineBreaks: true, // Help version tracking
        removeComments: true,
      });
    }
    return content;
  });
}
