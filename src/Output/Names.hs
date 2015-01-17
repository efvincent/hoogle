{-# LANGUAGE ViewPatterns, TupleSections, RecordWildCards, ScopedTypeVariables #-}

module Output.Names(writeNames, searchNames) where

import Language.Haskell.Exts
import Control.Applicative
import System.IO.Extra
import System.FilePath
import Data.List.Extra
import Data.Char
import Data.Maybe
import Data.Tuple.Extra
import qualified Data.ByteString.Char8 as BS

import Input.Type
import General.Util


writeNames :: Database -> [(Maybe Id, Items)] -> IO ()
writeNames (Database file) xs = writeFileBinary (file <.> "names") $ unlines
    [show i ++ " " ++ [' ' | isUName name] ++ lower name | (Just i, x) <- xs, name <- toName x]

toName :: Items -> [String]
toName (IKeyword x) = [x]
toName (IPackage x) = [x]
toName (IModule x) = [last $ splitOn "." x]
toName (IDecl x) = map fromName $ case x of
    TypeDecl _ name _ _ -> [name]
    DataDecl _ _ _ name _ _ _ -> [name]
    GDataDecl _ _ _ name _ _ _ _ -> [name]
    TypeFamDecl _ name _ _ -> [name]
    DataFamDecl _ _ name _ _ -> [name]
    ClassDecl _ _ name _ _ _ -> [name]
    TypeSig _ names _ -> names
    _ -> []

isUName (x:xs) = isUpper x
isUName _ = False

searchNames :: Database -> [String] -> IO [(Score, Id)]
searchNames (Database file) xs = do
    src <- BS.lines <$> BS.readFile (file <.> "names")
    return $ mapMaybe (match xs) src

match :: [String] -> BS.ByteString -> Maybe (Score, Id)
match xs = \str -> case second (BS.drop 1) $ BS.break (== ' ') str of
    (read . BS.unpack -> ident, str)
        | not $ all (`BS.isInfixOf` str) xsMatch -> Nothing
        | any (`BS.isPrefixOf` str) xsPerfect -> Just (0, ident)
        | any (`BS.isPrefixOf` str) xsGood -> Just (1, ident)
        | otherwise -> Just (2, ident)
    where
        xsMatch = map (BS.pack . lower) xs
        xsPerfect = [BS.pack $ [' ' | isUName x] ++ lower x | x <- xs]
        xsGood = [BS.pack $ [' ' | not $ isUName x] ++ lower x | x <- xs]