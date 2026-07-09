package nexus.campus.docs;

import nexus.campus.common.exception.ApiException;
import org.springframework.core.io.FileSystemResource;
import org.springframework.core.io.Resource;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RestController;

import java.nio.file.Files;
import java.nio.file.Path;

@RestController
public class PublicDocsController {

    private final Path publicRoot = Path.of(System.getProperty("user.dir")).getParent().resolve("public").normalize();

    @GetMapping("/llms.txt")
    public ResponseEntity<Resource> llms() {
        return file("llms.txt");
    }

    @GetMapping("/docs/{name:.+}")
    public ResponseEntity<Resource> docs(@PathVariable String name) {
        return file("docs/" + name);
    }

    @GetMapping("/.well-known/{name:.+}")
    public ResponseEntity<Resource> wellKnown(@PathVariable String name) {
        return file(".well-known/" + name);
    }

    @GetMapping("/schemas/{name:.+}")
    public ResponseEntity<Resource> schemas(@PathVariable String name) {
        return file("schemas/" + name);
    }

    private ResponseEntity<Resource> file(String relativePath) {
        Path path = publicRoot.resolve(relativePath).normalize();
        if (!path.startsWith(publicRoot) || !Files.isRegularFile(path)) {
            throw ApiException.notFound("public document", relativePath);
        }
        return ResponseEntity.ok()
                .contentType(mediaType(path.getFileName().toString()))
                .body(new FileSystemResource(path));
    }

    private MediaType mediaType(String name) {
        if (name.endsWith(".json")) return MediaType.APPLICATION_JSON;
        if (name.endsWith(".txt")) return MediaType.TEXT_PLAIN;
        if (name.endsWith(".md")) return MediaType.valueOf("text/markdown");
        if (name.endsWith(".html")) return MediaType.TEXT_HTML;
        return MediaType.APPLICATION_OCTET_STREAM;
    }
}
