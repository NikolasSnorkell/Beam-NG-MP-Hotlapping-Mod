const fs = require('fs');
const path = require('path');
const { execSync } = require('child_process');
const { rm, mkdir } = require('fs/promises');

// Конфигурация путей
const PATHS = {
    sourceServer: 'D:/Snorkell/beaemng_development/RaceHotlap/Hotlapping/Resources/Server/hotlapping',
    targetServer: 'D:/BeamDrift/Resources/Server/Hotlapping',
    sourceClient: 'D:/Snorkell/beaemng_development/RaceHotlap/Hotlapping/Resources/Client',
    targetClient: 'D:/BeamDrift/Resources/Client',
    zipPath: path.join(__dirname, 'Hotlapping.zip')
};

async function main() {
    try {
        // 1. Копирование серверных файлов
        console.log('Копирование серверных файлов...');
        await copyDirectory(PATHS.sourceServer, PATHS.targetServer);
        console.log('✓ Серверные файлы успешно скопированы\n');

        // 2. Архивация клиентских файлов
        console.log('Архивация клиентских файлов...');
        await createZipArchive(PATHS.sourceClient, PATHS.zipPath);
        console.log('✓ Клиентские файлы заархивированы');

        // 3. Перемещение архива
        console.log('Перемещение архива...');
        const finalZipPath = path.join(PATHS.targetClient, 'Hotlapping.zip');
        await moveFile(PATHS.zipPath, finalZipPath);
        console.log(`✓ Архив перемещен в: ${finalZipPath}`);

        console.log('\n✅ Все операции успешно завершены!');

    } catch (error) {
        console.error('❌ Критическая ошибка:', error.message);
        process.exit(1);
    }
}

// Копирование директории с перезаписью (исправленная версия)
async function copyDirectory(source, target) {
    // Проверяем существование исходной директории
    if (!fs.existsSync(source)) {
        throw new Error(`Исходная директория не существует: ${source}`);
    }

    // Создаем целевую директорию
    await mkdir(target, { recursive: true });

    // Преобразуем пути в формат Windows
    const winSource = source.replace(/\//g, '\\');
    const winTarget = target.replace(/\//g, '\\');

    try {
        // Выполняем robocopy с обработкой кодов возврата
        execSync(`robocopy "${winSource}" "${winTarget}" /E /MIR /NFL /NDL /NJH /NJS`, {
            stdio: 'inherit',
            windowsHide: true
        });
        
        // Проверяем код возврата (robocopy возвращает 0-7 как успех)
        return true;
    } catch (error) {
        // robocopy возвращает коды >7 при критических ошибках
        if (error.status > 7) {
            throw new Error(`Ошибка robocopy (код ${error.status}): ${getRobocopyError(error.status)}`);
        }
        // Коды 0-7 считаем успешными
        return true;
    }
}

// Функция для получения описания ошибки robocopy
function getRobocopyError(code) {
    const errors = {
        16: 'Серьезная ошибка. Robocopy не обработал файлы.',
        15: 'ОШИБКА(и) КОПИРОВАНИЯ',
        14: 'Несоответствие папок, ошибки файлов',
        13: 'Ошибки в файлах, несоответствие папок',
        12: 'Ошибки в файлах, несоответствие папок, несоответствие данных',
        11: 'Ошибки в файлах, несоответствие папок, несоответствие данных, несоответствие атрибутов',
        10: 'Несоответствие папок, несоответствие данных, несоответствие атрибутов',
        9: 'Несоответствие данных, несоответствие атрибутов',
        8: 'Несоответствие атрибутов'
    };
    return errors[code] || `Неизвестная ошибка robocopy (код ${code})`;
}

// Создание ZIP-архива (упрощенная версия)
async function createZipArchive(sourceDir, outputPath) {
    if (!fs.existsSync(sourceDir)) {
        throw new Error(`Исходная директория для архивации не существует: ${sourceDir}`);
    }

    // Очищаем предыдущий архив
    if (fs.existsSync(outputPath)) {
        await rm(outputPath);
    }

    // Используем 7-Zip если установлен, иначе PowerShell
    try {
        // Проверяем наличие 7-Zip
        execSync('7z', { stdio: 'ignore' });
        console.log('  Используем 7-Zip для архивации...');
        const winSource = sourceDir.replace(/\//g, '\\');
        const winOutput = outputPath.replace(/\//g, '\\');
        execSync(`7z a -tzip "${winOutput}" "${winSource}\\*"`, { stdio: 'inherit' });
    } catch {
        // Fallback на PowerShell
        console.log('  7-Zip не найден, используем PowerShell...');
        const winSource = sourceDir.replace(/\//g, '\\');
        const winOutput = outputPath.replace(/\//g, '\\');
        execSync(
            `powershell -Command "Compress-Archive -Path '${winSource}\\*' -DestinationPath '${winOutput}' -Force"`,
            { stdio: 'inherit' }
        );
    }
}

// Перемещение файла с перезаписью
async function moveFile(source, target) {
    await mkdir(path.dirname(target), { recursive: true });
    
    if (fs.existsSync(target)) {
        await rm(target);
    }
    
    await fs.promises.rename(source, target);
}

// Запуск главной функции
main();